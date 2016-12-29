-- **************************************************************************************
-- (c) Copyright 2008 ABB
--
-- The information contained in this document has to be kept strictly
-- confidential. Any unauthorised use, reproduction, distribution, 
-- or disclosure to third parties is strictly forbidden. 
-- ABB reserves all rights regarding Intellectual Property Rights
-- **************************************************************************************
-- File information
-- Document number: 		
-- Title:               FW- info module
-- File name:           fwInfo.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:            0.1
-- Prepared by:		SEROP/PRCB Magnus Tysell
-- Status:		Draft
-- Date:		2008-11-18
-- **************************************************************************************
-- References:
--
-- **************************************************************************************
-- Functional description:
-- When this CanOpen object (sdo) is addressed it will write all the FW-info via mailbox.vhd
-- to the mailbox Read buffer area.
--
-- Abbreviations:
-- MBX 			- mailbox
-- sdoType  - Part of the CanOpen objec index value.
--
-- **************************************************************************************
-- 0.01 - 090317 - PRCB/Magnus Tysell:
-- Changed process data length from 42 to 40 bytes.
-- **************************************************************************************
-- 0.02: 090420 - SEROP/PRCB Magnus Tysell
-- MIN_PWM_DELAY_TIME changed from 20us to 12us.
-- MAX_PWM_DELAY_TIME changed from 22us to 45us.
-- **************************************************************************************
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY fwInfo IS
  PORT (
    reset_n        : IN  STD_LOGIC;
    clk            : IN  STD_LOGIC;
    -- SDO signals:
    mbxIrq         : IN  STD_LOGIC;
    sdoType        : IN  STD_LOGIC_VECTOR (3 DOWNTO 0);
    rdDataReq      : OUT STD_LOGIC;
    rdAddr         : OUT STD_LOGIC_VECTOR (11 DOWNTO 0);
    rdData         : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
    rdDataValid    : IN  STD_LOGIC;
    wrDataReq      : OUT STD_LOGIC;
    wrAddr         : OUT STD_LOGIC_VECTOR (11 DOWNTO 0);
    wrData         : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
    wrDataBusy     : IN  STD_LOGIC;
    sdoOpCompleted : OUT STD_LOGIC;
    sdoOpError     : OUT STD_LOGIC;
    sdoOpErrorCode : OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
    );
END fwInfo;

ARCHITECTURE rtl OF fwInfo IS

  CONSTANT FW_INFO_LENGTH : INTEGER := 7;

  CONSTANT SM2_Length : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0028";  -- Length in bytes 
  CONSTANT SM3_Length : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0028";  -- Length in bytes  

  CONSTANT FW_VERSION                       : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0000";
  CONSTANT FW_REVISION                      : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0035";
  CONSTANT LATEST_SUPPORTED_ROBOCAT_VERSION : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0000";
  CONSTANT MIN_PWM_DELAY_TIME               : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"04B0";  -- =1200 100MHz ticks.
  CONSTANT MAX_PWM_DELAY_TIME               : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"1194";  -- =4500 100MHz ticks.
  CONSTANT PROCESS_DATA_OUTPUT_LENGTH       : STD_LOGIC_VECTOR(15 DOWNTO 0) := SM2_Length;
  CONSTANT PROCESS_DATA_INPUT_LENGTH        : STD_LOGIC_VECTOR(15 DOWNTO 0) := SM3_Length;

  TYPE FWInfo_t IS ARRAY (0 TO (FW_INFO_LENGTH -1)) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
  CONSTANT FW_INFO_ARRAY : FWInfo_t := ( FW_VERSION,
                                        FW_REVISION,
                                        LATEST_SUPPORTED_ROBOCAT_VERSION,
                                        MIN_PWM_DELAY_TIME,
                                        MAX_PWM_DELAY_TIME,
                                        PROCESS_DATA_OUTPUT_LENGTH,
                                        PROCESS_DATA_INPUT_LENGTH);

  CONSTANT CB_FIRMWARE_INFO : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"4001";

  SIGNAL index : INTEGER RANGE 0 TO (FW_INFO_LENGTH -1);

  TYPE FW_STATE_TYPE IS (Wait_For_Irq, Start_Write_FW_Info_Word, Wait_For_Write_Done);                            
  SIGNAL fw_state : FW_STATE_TYPE;	
  
  SIGNAL wrDataBusy_d : STD_LOGIC;
		
BEGIN
-------------------------------------------------------------------------------
-- FW info process
-------------------------------------------------------------------------------

  fw_info_ctrl : PROCESS (reset_n, clk) IS
  BEGIN
    IF reset_n = '0' THEN
      rdDataReq      <= '0';
      rdAddr         <= (OTHERS => '0');
      wrDataReq      <= '0';
      wrAddr         <= (OTHERS => '0');
      wrData         <= (OTHERS => '0');
      sdoOpCompleted <= '0';
      sdoOpError     <= '0';
      index          <= 0;
      sdoOpErrorCode <= (OTHERS => '0');
      wrDataBusy_d   <= '0';
    ELSIF clk'event AND clk = '1' THEN

      wrDataBusy_d <= wrDataBusy;

      CASE fw_state IS

        WHEN Wait_For_Irq             =>
          IF mbxIrq = '1' THEN          -- Mailbox event, start signal from the slavecontroller.
            IF sdoType = CB_FIRMWARE_INFO(3 DOWNTO 0) THEN  -- sdoType corresponds to CB_FIRMWARE_INFO, this sdo is addressed!
              fw_state     <= Start_Write_FW_Info_Word;
              index        <= 0;
            END IF;
          ELSE
            rdDataReq      <= '0';
            wrDataReq      <= '0';
            sdoOpCompleted <= '0';
            sdoOpError     <= '0';
            sdoOpErrorCode <= (OTHERS => '0');
          END IF;

        WHEN Start_Write_FW_Info_Word =>
          wrDataReq <= '1';
          wrAddr    <= conv_std_logic_vector(index,12);
          wrData    <= FW_INFO_ARRAY(index);
          fw_state  <= Wait_For_Write_Done;  

        WHEN Wait_For_Write_Done =>
          wrDataReq          <= '0';
          IF wrDataBusy_d = '1' AND wrDataBusy = '0' THEN  -- Write operation is done!
            IF index = (FW_INFO_LENGTH - 1) THEN  -- All FW-info data has been written, SDO operation completed!
              sdoOpCompleted <= '1';
              sdoOpError     <= '0';
              sdoOpErrorCode <= (OTHERS => '0');
              fw_state       <= Wait_For_Irq;
            ELSE
              index          <= index + 1;
              fw_state       <= Start_Write_FW_Info_Word;
            END IF;
          ELSE
            NULL;
          END IF;

      END CASE;
    END IF;
  END PROCESS fw_info_ctrl;
END rtl;

