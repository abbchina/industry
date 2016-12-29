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
-- Title:               FSL adapter for Power Unit Controller IP entity
-- File name:           duf_top/fsl_adapter.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:            0.03
-- Prepared by:         CNABB/Ye-Ye Zhang
-- Status:              Edited
-- Date:                2009-10-12
-- **************************************************************************************
-- Related files:       duf_top/Communication_top.vhd
-- **************************************************************************************
-- Functional description:
--
-- This is the FSL adapter for the Current Control IP implementation. FSL Bus width is 
-- 32 bit. The high 16 bit indicates the legacy address; and the low 16 bit indicates 
-- the data. When receive the FSL 32 bit data, FSL Adapter automatically check the 
-- legacy address, which should accords to input address. Otherwise, the data will be 
-- dropped with warning. No Register Array or DPM exists in FSL Adapter. The transfer 
-- data will be blocked in the buffer of FSL Bus. After one operation cycle is done, the 
-- FSL Adapter sends a done_fsl signal pulse.
--
-- **************************************************************************************
-- Revision 0.00 - 090925, CNABB/Ye-Ye Zhang
-- Created.
-- **************************************************************************************
-- Revision 0.01 - 090927, CNABB/Ye-Ye Zhang
-- Revised pdi related applications.
-- * Removed Read_Req and Write_Req states.
-- * Removed library UNISIM related.
-- **************************************************************************************
-- Revision 0.02 - 090930, CNABB/Ye-Ye Zhang
-- Revised fsl state machine.
-- * Modified a fsl timing error in FSL_S_Read and FSL_M_Write.
-- **************************************************************************************
-- Revision 0.03 - 091012, CNABB/Ye-Ye Zhang
-- Revised addCheck signal.
-- * Set "addrCheck <= (others => 'Z');" when necessary.
-- **************************************************************************************

-- **************************************************************************************
--
-- Definition of Ports
-- FSL_S_Clk       : Slave asynchronous clock
-- FSL_S_Read      : Read signal, requiring next available input to be read
-- FSL_S_Data      : Input data
-- FSL_S_CONTROL   : Control Bit, indicating the input data are control word
-- FSL_S_Exists    : Data Exist Bit, indicating data exist in the input FSL bus
-- FSL_M_Clk       : Master asynchronous clock
-- FSL_M_Write     : Write signal, enabling writing to output FSL bus
-- FSL_M_Data      : Output data
-- FSL_M_Control   : Control Bit, indicating the output data are contol word
-- FSL_M_Full      : Full Bit, indicating output FSL bus is full
--
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY fsl_adapter IS
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
    addr	          : in  std_logic_vector(15 downto 0);
    done           : OUT STD_LOGIC
    );
  ATTRIBUTE SIGIS : STRING;
  ATTRIBUTE SIGIS OF clk : SIGNAL IS "Clk"; 
  ATTRIBUTE SIGIS OF FSL_S_Clk : SIGNAL IS "Clk"; 
  ATTRIBUTE SIGIS OF FSL_M_Clk : SIGNAL IS "Clk";
END fsl_adapter;

ARCHITECTURE Behavioral OF fsl_adapter IS

-------------------------------------------------------------------------------
-- Signal declarations:
-------------------------------------------------------------------------------

  TYPE STATE_TYPE IS (Idle, Read_FSL, Write_FSL, WaitCheck);
  SIGNAL fsl_state : STATE_TYPE;
  SIGNAL addrCheck : STD_LOGIC_VECTOR(15 downto 0);
  SIGNAL done_i    : STD_LOGIC;

  -- shows it is in the WRITE_FSL state 
  SIGNAL writeFslFlag     : STD_LOGIC;
  -- shows it is in the READ_FSL state
  SIGNAL readFslFlag      : STD_LOGIC;
	
BEGIN

  done          <= done_i;
  -- FSL settings
  FSL_S_Clk     <= clk;
  FSL_M_Clk     <= clk;
  FSL_M_Control <= '0';

  -- send out read request when in READ_FSL state
  FSL_S_Read    <= FSL_S_Exists   WHEN readFslFlag = '1'  ELSE '0';
  -- send out write request when in WRITE_FSL state
  FSL_M_Write   <= NOT FSL_M_Full WHEN writeFslFlag = '1' ELSE '0';

-------------------------------------------------------------------------------
-- FSL Adapter State Machine
-------------------------------------------------------------------------------
  PROCESS(clk, reset_n)
  BEGIN
    IF (reset_n = '0') THEN
      fsl_state   <= Idle;
      data_out    <= (others => 'Z');
      FSL_M_Data  <= (others => '0');
		addrCheck   <= (others => 'Z');
      done_i      <= '0';
      writeFslFlag     <= '0';
      readFslFlag      <= '0';
    ELSIF (clk'event AND clk = '1') THEN

      CASE fsl_state IS

        WHEN Idle => 
          IF (done_i = '1') THEN
			   done_i <= '0';
          ELSE
			   IF (rden = '1') THEN
              fsl_state <= Read_FSL;
            ELSIF (wren = '1') THEN
              fsl_state <= Write_FSL;
            END IF;
          END IF;

        WHEN Read_FSL => 
          IF (FSL_S_Exists = '1') THEN
            readFslFlag     <= '1';
			   addrCheck   <= FSL_S_Data(0 to 15);
            data_out    <= FSL_S_Data(16 to 31);
            fsl_state   <= WaitCheck;
          END IF;

        WHEN Write_FSL => 
          IF (FSL_M_Full = '0') THEN
				writeFslFlag    <= '1';
            FSL_M_Data(0 to 15)  <= addr;
            FSL_M_Data(16 to 31) <= data_in;
            fsl_state   <= WaitCheck;
          END IF;

        WHEN WaitCheck =>
          writeFslFlag     <= '0';
          readFslFlag      <= '0';
		    IF (rden = '1') THEN
			   IF (addr = addrCheck) THEN
				  addrCheck <= (others => 'Z');
				  fsl_state <= Idle;
              done_i    <= '1';
				ELSE
              fsl_state <= Read_FSL;
			   END IF;
          ELSIF (wren = '1') THEN
			   fsl_state <= Idle;
            done_i    <= '1';
			 ELSE
			   fsl_state <= Idle;
			 END IF;

      END CASE;
    END IF;
  END PROCESS;

END Behavioral;
