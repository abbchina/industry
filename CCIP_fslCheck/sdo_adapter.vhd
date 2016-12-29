-- **************************************************************************************
-- (c) Copyright 2009 ABB
--
-- The information contained in this document has to be kept strictly
-- confidential. Any unauthorised use, reproduction, distribution, 
-- or disclosure to third parties is strictly forbidden. 
-- ABB reserves all rights regarding Intellectual Property Rights
-- **************************************************************************************
-- File information
-- Document number: 		
-- Title:               SDO adapter state machine entity
-- File name:           duf_sc/sdo_adapter.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:            0.01
-- Prepared by:         CNABB/Ye-Ye Zhang
-- Status:              Edited
-- Date:                2009-09-29
-- **************************************************************************************
-- Related files:       duf_sc/SlaveController_top.vhd
--                      duf_sc/comm_dpm_controller.vhd
-- **************************************************************************************
-- Functional description:
-- 
-- This SDO adapter copies data between the FSL bus and the SDO process. So the original
-- mailbox application mechanism was totally replaced with this SDO adapter.
--
-- **************************************************************************************
-- Revision 0.00 - 090927, CNABB/Ye-Ye Zhang
-- Created.
-- **************************************************************************************
-- Revision 0.01 - 090929, CNABB/Ye-Ye Zhang
-- Removed reduntant constants and signals
-- * Removed CanOpen constants. 
-- * Removed Mailbox signals.
-- * Removed CoE signals.
-- * Removed FoE signals.
-- * Removed SPI related constants and signals.
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY sdo_adapter IS
  PORT(
    reset_n           : IN  STD_LOGIC;
    clk               : IN  STD_LOGIC;
    --Communication DPM signals:
    comm_dpm_web      : OUT STD_LOGIC;
    comm_dpm_dinb     : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
    comm_dpm_doutb    : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
    comm_dpm_addrb    : OUT STD_LOGIC_VECTOR (5 DOWNTO 0);
    ctrl_dpm          : OUT STD_LOGIC;
    -- Slavecontroller signals:
    sdoWriteEvent     : IN  STD_LOGIC;
    sdoReadEvent      : IN  STD_LOGIC;
    done              : OUT STD_LOGIC;
    -- signals to memUnits:
    mbxIrq            : OUT STD_LOGIC;
    memSel            : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
    rdDataReq         : IN  STD_LOGIC;
    rdAddr            : IN  STD_LOGIC_VECTOR (11 DOWNTO 0);
    rdData            : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
    rdDataValid       : OUT STD_LOGIC;
    wrDataReq         : IN  STD_LOGIC;
    wrAddr            : IN  STD_LOGIC_VECTOR (11 DOWNTO 0);
    wrData            : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
    wrDataBusy        : OUT STD_LOGIC;
    OpCompleted       : IN  STD_LOGIC;
    OpError           : IN  STD_LOGIC;
    OpErrorCode       : IN  STD_LOGIC_VECTOR(3 DOWNTO 0)
    );
END sdo_adapter;

ARCHITECTURE rtl OF sdo_adapter IS

  COMPONENT comm_dpm_controller
    PORT(
      reset_n        : IN  STD_LOGIC;
      clk            : IN  STD_LOGIC;
      comm_dpm_web   : OUT STD_LOGIC;
      comm_dpm_dinb  : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      comm_dpm_doutb : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      comm_dpm_addrb : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
      ctrl_register  : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      data_in        : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      data_out       : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      addr           : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      done           : OUT STD_LOGIC
      );
  END COMPONENT;

-------------------------------------------------------------------------------
-- Signal declarations:
-------------------------------------------------------------------------------

  -- Legacy SM address
  CONSTANT SM0_Start_Addr : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"1600";
  CONSTANT SM0_Length     : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0130";  -- Length in bytes
  CONSTANT SM1_Start_Addr : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"1750";
  CONSTANT SM1_Length     : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0130";  -- Length in bytes
  -- Legacy MB address
  CONSTANT MB_HEADER_SIZE : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0006";	
  CONSTANT MB_WRITE_Buffer_Start_Addr      : STD_LOGIC_VECTOR(15 DOWNTO 0) := (SM0_Start_Addr);
  CONSTANT MB_WRITE_Buffer_End_Addr        : STD_LOGIC_VECTOR(15 DOWNTO 0) := (SM0_Start_Addr + SM0_Length - 2);
  CONSTANT MB_WRITE_Buffer_Data_Start_Addr : STD_LOGIC_VECTOR(15 DOWNTO 0) := (SM0_Start_Addr + MB_HEADER_SIZE);
  CONSTANT MB_READ_Buffer_Start_Addr      : STD_LOGIC_VECTOR(15 DOWNTO 0) := (SM1_Start_Addr);
  CONSTANT MB_READ_Buffer_End_Addr        : STD_LOGIC_VECTOR(15 DOWNTO 0) := (SM1_Start_Addr + SM1_Length -2);
  CONSTANT MB_READ_Buffer_Data_Start_Addr : STD_LOGIC_VECTOR(15 DOWNTO 0) := (SM1_Start_Addr + MB_HEADER_SIZE);
  -- SDO data address
  CONSTANT SDO_HEADER_SIZE            : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0008";  -- 8 bytes
  CONSTANT SDO_DATA_WRITE_BUFFER_ADDR : STD_LOGIC_VECTOR(15 DOWNTO 0) := MB_WRITE_Buffer_Data_Start_Addr + SDO_HEADER_SIZE + 2;
  CONSTANT SDO_DATA_READ_BUFFER_ADDR  : STD_LOGIC_VECTOR(15 DOWNTO 0) := MB_READ_Buffer_Data_Start_Addr + SDO_HEADER_SIZE + 2;
  -- SDO state machine
  TYPE MB_STATE_TYPE IS ( Wait_For_Run_Mailbox, Get_SDO_Type, Running_SDO_Services, Run_SDO_Read, Run_SDO_Write);                            
  SIGNAL mb_state      : MB_STATE_TYPE;
  -- Supported files and properties
  CONSTANT FILE_LOCATION_ADDR        : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0770";
  -- Defines for file locations: (Matching the SDO-type(3 downto 0)!)
  CONSTANT RESERVED_LOCATION         : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"0";  -- Can we change so that the "0" is reserved and "5" = "applic_conf_data"???
  CONSTANT FPGA_FW_INFO_MEM          : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"1";
  CONSTANT EEPROM_MEM                : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"2";  -- Same for "2" = PB_Calibration_data and "3" = PB_HW_info.
  CONSTANT FLASH_MEM                 : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"4";
  CONSTANT FPGA_APPLIC_CONF_DATA_MEM : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"5";
  -- DPM control signals
  SIGNAL cdc_ctrl_register : STD_LOGIC_VECTOR (15 DOWNTO 0);
  SIGNAL cdc_write_data    : STD_LOGIC_VECTOR (15 DOWNTO 0);
  SIGNAL cdc_read_data     : STD_LOGIC_VECTOR (15 DOWNTO 0);
  SIGNAL cdc_addr          : STD_LOGIC_VECTOR (15 DOWNTO 0);
  SIGNAL cdc_done          : STD_LOGIC;

BEGIN

-------------------------------------------------------------------------------
-- SDO adapter process
-------------------------------------------------------------------------------
  sdo_ctrl : PROCESS (reset_n, clk)
  VARIABLE tmpSize : STD_LOGIC_VECTOR(11 DOWNTO 0);
  BEGIN
    IF reset_n = '0' THEN
      done                <= '0';
      ctrl_dpm            <= '0';
      cdc_ctrl_register   <= (OTHERS => '0');
      cdc_write_data      <= (OTHERS => '0');
      cdc_addr            <= (OTHERS => '0');
      mb_state            <= Wait_For_Run_Mailbox;
      mbxIrq              <= '0';
      rdData              <= (OTHERS => '0');
      rdDataValid         <= '0';
      wrDataBusy          <= '0';
      memSel              <= RESERVED_LOCATION;
    ELSIF clk'event AND clk = '1' THEN

      CASE mb_state IS

        WHEN Wait_For_Run_Mailbox => 
          IF sdoWriteEvent = '1' THEN
            -- Mailbox event, start signal from the slavecontroller.
            -- The mailbox write buffer has been written to (is full).
            mb_state     <= Get_SDO_Type;
          ELSIF sdoReadEvent = '1' THEN
            -- The mailbox read buffer has been read by the ethercat master.
            -- Master has read the mailbox read buffer. But the 
            -- FoE Read access not been started. Pull down the IRQ and finalize mailbox!
            mb_state     <= Get_SDO_Type;
          ELSE
            -- No IRQ!
            done         <= '0';
            mb_state     <= Wait_For_Run_Mailbox;
          END IF;

        WHEN Get_SDO_Type =>
          --Reads the SDO Type register, which defines the file location
          IF cdc_done = '1' THEN
            ctrl_dpm <= '0'; 
            cdc_ctrl_register(0) <= '0';
				mbxIrq <= '1';
            memSel <= cdc_read_data(3 DOWNTO 0);
            mb_state <= Running_SDO_Services;
          ELSE
            cdc_addr <= FILE_LOCATION_ADDR;
            ctrl_dpm <= '1';
            --Start a read ECS register access
            cdc_ctrl_register(0) <=	'1';
            mb_state <= Get_SDO_Type;
          END IF;

        -- Waiting for read/write requests from the addressed SDO:
        WHEN Running_SDO_Services =>
          mbxIrq                 <= '0';  -- (pull down again, pulse only)
          rdDataValid            <= '0';
          IF wrDataReq = '1' THEN
            -- Write request from SDO.
            cdc_addr             <= (SDO_DATA_READ_BUFFER_ADDR + (wrAddr & '0'));
            cdc_write_data       <= wrData;
            wrDataBusy           <= '1';
            ctrl_dpm             <= '1';
            cdc_ctrl_register(1) <= '1';
            mb_state             <= Run_SDO_Write;
          ELSIF rdDataReq = '1' THEN
            -- Read request from SDO.
            rdDataValid          <= '0';
            cdc_addr             <= (SDO_DATA_WRITE_BUFFER_ADDR + (rdAddr & '0'));
            ctrl_dpm             <= '1';
            cdc_ctrl_register(0) <= '1';
            mb_state             <= Run_SDO_Read;
          ELSIF OpCompleted = '1' THEN
            IF OpError = '1' THEN
              -- An error in SDO. 
              done         <= '1';
              mb_state     <= Wait_For_Run_Mailbox;
            ELSE
              done         <= '1';
              mb_state     <= Wait_For_Run_Mailbox;
            END IF;
          END IF;

        -- Waiting for the Register read operation to finalize: 
        WHEN Run_SDO_Read =>
          IF cdc_done = '1' THEN
            ctrl_dpm             <= '0';
            cdc_ctrl_register(0) <= '0';
            rdData               <= cdc_read_data(15 DOWNTO 0);
            rdDataValid          <= '1';
            mb_state             <= Running_SDO_Services;
          END IF;

        -- Waiting for the Register write operation to finalize: 
        WHEN Run_SDO_Write => 
          IF cdc_done = '1' THEN
            ctrl_dpm 	<= '0';
            cdc_ctrl_register(1) <= '0';
            wrDataBusy <= '0';
            mb_state <= Running_SDO_Services;
          END IF;

      END CASE;
    END IF;
  END PROCESS sdo_ctrl;

-------------------------------------------------------------------------------
-- Component instatiations: 
-------------------------------------------------------------------------------	

  comm_dpm_controller_inst : comm_dpm_controller
    PORT MAP(
      reset_n        => reset_n,
      clk            => clk,
      comm_dpm_web   => comm_dpm_web,
      comm_dpm_dinb  => comm_dpm_dinb,
      comm_dpm_doutb => comm_dpm_doutb,
      comm_dpm_addrb => comm_dpm_addrb,
      ctrl_register  => cdc_ctrl_register,
      data_in        => cdc_write_data,
      data_out       => cdc_read_data,
      addr           => cdc_addr,
      done           => cdc_done
      );

END rtl;

