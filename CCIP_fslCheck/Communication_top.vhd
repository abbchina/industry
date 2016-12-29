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
--	Title:					Communication Module top entity
--	File name:				duf_top/Communication_top.vhd
-- **************************************************************************************
-- Revision information
-- Revision index: 		0
-- Revision:				0.01
--	Prepared by:			CNABB/Ye-Ye Zhang
-- Status:					Edited
-- Date:						2009-09-25
-- **************************************************************************************
-- Related files:       duf_top/duf_ip_top.vhd
--                      duf_top/fsl_adapter.vhd
--                      sc_dpm/sc_dpm.vhd
-- **************************************************************************************
-- Functional description:
-- 
-- This module handles the communication between the CPU interface and communication DPM 
-- through the FSL bus. It also validates and calculates the basic format conversion for 
-- output and input process data, respectively.
-- 
-- **************************************************************************************
-- Revision 0.00 - 090925, SEROP/PRCB Magnus Tysell
-- Copied from Communication_top.vhd (Revision 0.6).
-- **************************************************************************************
-- Revision 0.01 - 090925, CNABB/Ye-Ye Zhang
-- Replaced uController with FSL adapter.
-- * Removed pdi_async_uController_sc component.
-- * Added FSL adapter.
-- * Removed library UNISIM related.
-- * Changed ECS_ constants to FSL_ constants.
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY Communication_top IS
  PORT(
    reset_n        : IN    STD_LOGIC;
    clk            : IN    STD_LOGIC;
    -- FSL ports
    -- DO NOT EDIT BELOW THIS LINE ---------------------
    -- Bus protocol ports, do not add or delete. 
    FSL_S_Clk      : out   std_logic;
    FSL_S_Read     : out   std_logic;
    FSL_S_Data     : in    std_logic_vector(0 to 31);
    FSL_S_Control  : in    std_logic;
    FSL_S_Exists   : in    std_logic;
    FSL_M_Clk      : out   std_logic;
    FSL_M_Write    : out   std_logic;
    FSL_M_Data     : out   std_logic_vector(0 to 31);
    FSL_M_Control  : out   std_logic;
    FSL_M_Full     : in    std_logic;
    -- DO NOT EDIT ABOVE THIS LINE ---------------------
    -- DPM signals
    comm_dpm_web   : IN    STD_LOGIC;
    comm_dpm_dinb  : IN    STD_LOGIC_VECTOR (15 DOWNTO 0);
    comm_dpm_doutb : OUT   STD_LOGIC_VECTOR (15 DOWNTO 0);
    comm_dpm_addrb : IN    STD_LOGIC_VECTOR (5 DOWNTO 0)
    );
END Communication_top;

ARCHITECTURE Behavioral OF Communication_top IS

  COMPONENT fsl_adapter IS
    PORT(
      reset_n        : in  std_logic;
      clk            : in  std_logic;
      -- FSL ports
	   -- DO NOT EDIT BELOW THIS LINE ---------------------
      -- Bus protocol ports, do not add or delete. 
      FSL_S_Clk      : out std_logic;
      FSL_S_Read     : out std_logic;
      FSL_S_Data     : in  std_logic_vector(0 to 31);
      FSL_S_Control  : in  std_logic;
      FSL_S_Exists   : in  std_logic;
      FSL_M_Clk      : out std_logic;
      FSL_M_Write    : out std_logic;
      FSL_M_Data     : out std_logic_vector(0 to 31);
      FSL_M_Control  : out std_logic;
      FSL_M_Full     : in  std_logic;
      -- DO NOT EDIT ABOVE THIS LINE ---------------------
      -- Comm internal signals
		wren           : in  std_logic;
      rden           : in  std_logic;
      data_in        : in  std_logic_vector(15 downto 0);
      data_out       : out std_logic_vector(15 downto 0);
      addr	         : in  std_logic_vector(15 downto 0);
      done           : OUT STD_LOGIC
      );
  END COMPONENT;

  COMPONENT sc_dpm
    PORT(
      addra : IN  STD_LOGIC_VECTOR(5 DOWNTO 0);
      addrb : IN  STD_LOGIC_VECTOR(5 DOWNTO 0);
      clka  : IN  STD_LOGIC;
      clkb  : IN  STD_LOGIC;
      dina  : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      dinb  : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      douta : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      wea   : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);
      web   : IN  STD_LOGIC_VECTOR(0 DOWNTO 0)
      );
  END COMPONENT;

-------------------------------------------------------------------------------
-- Signal declarations:
-------------------------------------------------------------------------------

  -- DPM address
  CONSTANT CTRL_REG_ADDR                      : STD_LOGIC_VECTOR(5 DOWNTO 0) := B"00_0000";
  CONSTANT DATA_REG_ADDR                      : STD_LOGIC_VECTOR(5 DOWNTO 0) := B"00_0011";
  CONSTANT ADDR_REG_ADDR                      : STD_LOGIC_VECTOR(5 DOWNTO 0) := B"00_0100";
  CONSTANT DPM_Process_Data_Output_Start_Addr : STD_LOGIC_VECTOR(5 DOWNTO 0) := B"00_0101";
  CONSTANT DPM_Process_Data_Input_Start_Addr  : STD_LOGIC_VECTOR(5 DOWNTO 0) := B"01_1000"; 
  -- FSL address
  CONSTANT FSL_Process_Data_Output_Start_Addr : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"1100"; 
  CONSTANT FSL_Process_Data_Input_Start_Addr  : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"1300";
  -- Register signals
  SIGNAL ctrl_reg      : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL addr_reg_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
  -- Process data words
  CONSTANT PROCESS_DATA_LENGTH  : STD_LOGIC_VECTOR(5 DOWNTO 0) := B"10_1000";  -- Number of bytes = 40.
  CONSTANT NR_OF_WORDS          : STD_LOGIC_VECTOR(4 DOWNTO 0) := PROCESS_DATA_LENGTH(5 downto 1);  -- PROCESS_DATA_LENGTH/2.
  SIGNAL wordPtr : std_logic_vector(5 downto 0);
  -- FSL adapter signals
  SIGNAL addr       : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL write_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL read_data  : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL read_en   : STD_LOGIC;
  SIGNAL write_en  : STD_LOGIC;
  SIGNAL done_fsl   : STD_LOGIC;
  -- DPM signals
  SIGNAL dpm_wea    : STD_LOGIC;
  SIGNAL dpm_douta  : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL dpm_dina   : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL dpm_addra  : std_logic_vector(5 downto 0);
  -- State Machine signals
  TYPE COMM_STATE_TYPE IS (Idle, Wait_Cmd, Read_Register, Write_Register_Prepare, Write_Register, Read_Process_Data, Write_Process_Data, Clear_Command, Delay);
  SIGNAL comm_state : COMM_STATE_TYPE;
  SIGNAL next_state : COMM_STATE_TYPE;

BEGIN

-------------------------------------------------------------------------------
-- Communication Controller State Machine
-------------------------------------------------------------------------------
  comm_ctrl : PROCESS (reset_n, clk) IS
  BEGIN
    IF reset_n = '0' THEN
      addr          <= (OTHERS => '0');
      write_data    <= (OTHERS => '0');
      read_en       <= '0';
      write_en      <= '0';
      dpm_addra     <= (OTHERS => '0');
      dpm_dina      <= (OTHERS => '0');
      dpm_wea       <= '0';
      ctrl_reg      <= (OTHERS => '0');
      addr_reg_data <= (OTHERS => '0');
      comm_state    <= Idle;
      wordPtr       <= (OTHERS => '0');
    ELSIF clk'event AND clk = '1' THEN

      CASE comm_state IS

        WHEN Idle =>
          dpm_wea    <= '0';
          ctrl_reg   <= X"0000";
          dpm_addra  <= CTRL_REG_ADDR;
          next_state <= Wait_Cmd;
          comm_state <= Delay;

        WHEN Wait_Cmd =>
          ctrl_reg        <= dpm_douta;
          IF ctrl_reg(0) = '1' THEN
            --read register command
            dpm_addra     <= ADDR_REG_ADDR;
            next_state    <= Read_Register;
            comm_state    <= Delay;
          ELSIF ctrl_reg(1) = '1' THEN
            --write register command
            dpm_addra     <= ADDR_REG_ADDR;
            next_state    <= Write_Register_Prepare;
            comm_state    <= Delay;
          ELSIF ctrl_reg(2) = '1' THEN
            --read process data command
            addr          <= FSL_Process_Data_Output_Start_Addr;
            dpm_addra     <= DPM_Process_Data_Output_Start_Addr;
            wordPtr       <= (OTHERS => '0'); 
            comm_state    <= Read_Process_Data;
          ELSIF ctrl_reg(3) = '1' THEN
            --write process data command
            addr          <= FSL_Process_Data_Input_Start_Addr;
            dpm_addra     <= DPM_Process_Data_Input_Start_Addr;  
            wordPtr       <= (OTHERS => '0');  
            comm_state    <= Delay;
            next_state    <= Write_Process_Data;
          ELSE
            comm_state    <= Wait_Cmd;
          END IF;

        WHEN Read_Register =>
          --Reads register content from slave
          IF done_fsl = '1' AND read_en = '1' THEN
            read_en       <= '0';
            dpm_dina      <= read_data;
            dpm_addra     <= DATA_REG_ADDR;
            dpm_wea       <= '1';
            comm_state    <= Clear_Command;
          ELSE
            addr          <= dpm_douta;
            read_en       <= '1';
            comm_state    <= Read_Register;
          END IF;

        WHEN Write_Register_Prepare =>
          --Stores target address and reads data
          addr_reg_data   <= dpm_douta;
          dpm_addra       <= DATA_REG_ADDR;
          next_state      <= Write_Register;
          comm_state      <= Delay;
          
        WHEN Write_Register =>
          --Writes data to register in slave
          IF done_fsl = '1' AND write_en = '1' THEN
            write_en      <= '0';
            comm_state    <= Clear_Command;
          ELSE
            addr          <= addr_reg_data;
            write_data    <= dpm_douta;
            write_en      <= '1';
            comm_state    <= Write_Register;
          END IF;

        WHEN Read_Process_Data =>
          --Reads Process data from Slave and writes to DPM
          IF done_fsl = '1' AND read_en = '1' THEN
            dpm_dina      <= read_data;
            read_en       <= '0';
            dpm_wea       <= '1';
            wordPtr       <= wordPtr + '1';
          ELSE
            IF wordPtr = NR_OF_WORDS THEN
              comm_state  <= Clear_Command;
            ELSE 
              dpm_wea     <= '0';
              read_en     <= '1';
              addr        <= FSL_Process_Data_Output_Start_Addr + (wordPtr & '0');              
              dpm_addra   <= DPM_Process_Data_Output_Start_Addr + wordPtr;
              comm_state  <= Read_Process_Data;
            END IF;
          END IF;


        WHEN Write_Process_Data =>
          --Reads Process data from COMM DPM and writes to Slave
          IF done_fsl = '1' AND write_en = '1' THEN
            dpm_dina      <= read_data;
            write_en      <= '0';
            wordPtr       <= wordPtr + '1';
            dpm_addra     <= DPM_Process_Data_Input_Start_Addr + wordPtr + '1';
            comm_state    <= Delay;
            next_state    <= Write_Process_Data;
          ELSE
            IF wordPtr = NR_OF_WORDS THEN
              comm_state  <= Clear_Command;
            ELSE 
              addr        <= FSL_Process_Data_Input_Start_Addr + (wordPtr & '0');
              write_en    <= '1';
              write_data  <= dpm_douta;
              comm_state  <= Write_Process_Data;
            END IF;
          END IF;
            

        WHEN Clear_Command =>
          --Clears all active commands
          dpm_wea         <= '1';
          dpm_dina        <= (OTHERS => '0');
          dpm_addra       <= CTRL_REG_ADDR;
          comm_state      <= Idle;

        WHEN Delay =>
          --Delays by one cycle 
          comm_state      <= next_state;

      END CASE;
    END IF;
  END PROCESS comm_ctrl;

-------------------------------------------------------------------------------
-- Component instatiations: 
-------------------------------------------------------------------------------	

  fsl_adapter_inst : fsl_adapter
    PORT MAP(
      reset_n         => reset_n,
      clk             => clk,
      -- FSL ports
      -- DO NOT EDIT BELOW THIS LINE ---------------------
      -- Bus protocol ports, do not add or delete. 
		FSL_S_Clk       => FSL_S_Clk,
		FSL_S_Read      => FSL_S_Read,
		FSL_S_Data      => FSL_S_Data,
		FSL_S_Control   => FSL_S_Control,
		FSL_S_Exists    => FSL_S_Exists,
		FSL_M_Clk       => FSL_M_Clk,
		FSL_M_Write     => FSL_M_Write,
		FSL_M_Data      => FSL_M_Data,
		FSL_M_Control   => FSL_M_Control,
		FSL_M_Full      => FSL_M_Full,
      -- DO NOT EDIT ABOVE THIS LINE ---------------------
      -- DPM signals
      wren            => write_en,
      rden            => read_en,
      data_in         => write_data,
      data_out        => read_data, 
      addr            => addr,
      done            => done_fsl
      );

  comm_dpm_inst : sc_dpm
    PORT MAP (
      addra           => dpm_addra,
      addrb           => comm_dpm_addrb,
      clka            => clk,
      clkb            => clk,
      dina            => dpm_dina,
      dinb            => comm_dpm_dinb,
      douta           => dpm_douta,
      doutb           => comm_dpm_doutb,
      wea(0)          => dpm_wea,
      web(0)          => comm_dpm_web
      );

END Behavioral;

