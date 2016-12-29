-- **************************************************************************************
-- (c) Copyright 2009 ABB
--
-- Any unauthorised use, reproduction, distribution, or disclosure to third parties is 
-- strictly forbidden. ABB reserves all rights regarding Intellectual Property Rights.
-- **************************************************************************************
-- File information
-- Document number: 		
-- Title:               FSL Emulator Testbench Module
-- File name:           duf_tb/fsl_emu_tb.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:            0.11
-- Prepared by:         CNABB/Ye-Ye Zhang
-- Status:              Edited
-- Date:                2009-12-03
-- **************************************************************************************
-- Related files:       duf_tb/duf_ip_top_tb.vhd
-- **************************************************************************************
-- Functional description:
-- 
-- It is the emulator of the FSL interface.
-- 
-- **************************************************************************************
-- Revision 0.01 - 090311, CNABB/Dream-Shengping Tu
-- Modify the names of the signals according to the vhdl code convention.
-- ************************************************************************************** 
-- Revision 0.03 - 090929, CNABB/Ye-Ye Zhang
-- Revised FSL read/write orders and logics.
-- * Converted read and write orders. 
-- ************************************************************************************** 
-- Revision 0.04 - 091009, CNABB/Ye-Ye Zhang
-- Revised FSL read/write state machine.
-- * Either renamed or added status: INIT_READ, PREOP_WRITE, PREOP_READ, CFG_CMD_WRITE, 
--                                   CFG_DATA_WRITE, SAFEOP_WRITE, SAFEOP_READ, 
--                                   OP_WRITE, OP_READ, RUN_DATA_WRITE, RUN_DATA_READ.
-- ************************************************************************************** 
-- Revision 0.05 - 091012, CNABB/Ye-Ye Zhang
-- Revised FSL read/write orders and logics.
-- * Converted CFG_DATA_ARRAY constants orders. 
-- * Added RUN_DATA_ARRAY constants.
-- * Added states: IDLE, RUN_CMD_WRITE.
-- ************************************************************************************** 
-- Revision 0.06 - 091013, CNABB/Ye-Ye Zhang
-- Revised FSL read/write orders and logics.
-- * Changed alStatus(4) from '1' to '0' in ESM_AL_INIT/PREOP/SAFEOP/OP constants.
-- ************************************************************************************** 
-- Revision 0.07 - 091020, CNABB/Ye-Ye Zhang
-- Renamed from puc to duf.
-- * Replaced Power Unit Controller with Drive Unit Firmware.
-- ************************************************************************************** 
-- Revision 0.08 - 091028, CNABB/Ye-Ye Zhang
-- Modified CFG_DATA_ARRAY and RUN_DATA_ARRAY constants configuration.
-- * Changed CFG_DATA_ARRAY[16] from 2000 to 1000.
-- * Changed CFG_DATA_ARRAY[17] from 2000 to 6300.
-- * Changed RUN_DATA_ARRAY[1] from X"11020004" to X"11020005".
-- ************************************************************************************** 
-- Revision 0.09 - 091030, CNABB/Ye-Ye Zhang
-- Modified RUN_DATA_ARRAY constants configuration.
-- * Updated RUN_DATA_ARRAY totally.
-- * Updated corresponding RefSeq Serial Number in state machine.
-- ************************************************************************************** 
-- Revision 0.10 - 091102, CNABB/Ye-Ye Zhang
-- Added FW INFO function test bench.
-- * Added states: FWINFO_CMD_WRITE, FWINFO_DATA_READ.
-- * Updated state convertion orders.
-- ************************************************************************************** 
-- Revision 0.11 - 091203, CNABB/Ye-Ye Zhang
-- Revised FSL orders for test bench.
-- * Replaced INIT_READ state with INIT_DATA_READ state.
-- * Added states: INIT_WRITE, INIT_READ.
-- * Updated state convertion orders.
-- * Either renamed or added status: INIT_DATA_READ, 
--                                   INIT_WRITE, INIT_READ, 
--                                   PREOP_WRITE, PREOP_READ, 
--                                   FWINFO_CMD_WRITE, FWINFO_DATA_READ, 
--                                   CFG_CMD_WRITE, CFG_DATA_WRITE, 
--                                   SAFEOP_WRITE, SAFEOP_READ, 
--                                   OP_WRITE, OP_READ, 
--                                   RUN_DATA_WRITE, RUN_DATA_READ, 
--                                   IDLE.
-- ************************************************************************************** 

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY fsl_emu_tb IS
  PORT(
    FSL_Clk              : IN  STD_LOGIC;
    FSL_Rst              : IN  STD_LOGIC;
    FSL_S_Clk            : IN  STD_LOGIC;
    FSL_S_Read           : IN  STD_LOGIC;
    FSL_S_Data           : OUT STD_LOGIC_VECTOR(0 TO 31);
    FSL_S_Control        : OUT STD_LOGIC;
    FSL_S_Exists         : OUT STD_LOGIC;
    FSL_M_Clk            : IN  STD_LOGIC;
    FSL_M_Write          : IN  STD_LOGIC;
    FSL_M_Data           : IN  STD_LOGIC_VECTOR(0 TO 31);
    FSL_M_Control        : IN  STD_LOGIC;
    FSL_M_Full           : OUT STD_LOGIC
    );
END fsl_emu_tb;

ARCHITECTURE BEHAVIORAL OF fsl_emu_tb IS

  -- the number of words read from FSL
  CONSTANT NUMBER_OF_INPUT_WORDS  : NATURAL := 20;
  -- the number of words to write to FSL    
  CONSTANT NUMBER_OF_OUTPUT_WORDS : NATURAL := 20;
  -- number of read signals
  SIGNAL readNum   : NATURAL RANGE 0 TO NUMBER_OF_INPUT_WORDS - 1;	
  -- number of write signals
  SIGNAL writeNum  : NATURAL RANGE 0 TO NUMBER_OF_OUTPUT_WORDS - 1;
  -- transmit signals
  CONSTANT CMD_AL_CONTROL     : STD_LOGIC_VECTOR(31 DOWNTO 0) := X"02200001";
  CONSTANT ESM_AL_INIT        : STD_LOGIC_VECTOR(31 DOWNTO 0) := X"01200001";
  CONSTANT ESM_AL_PREOP       : STD_LOGIC_VECTOR(31 DOWNTO 0) := X"01200002";
  CONSTANT ESM_AL_SAFEOP      : STD_LOGIC_VECTOR(31 DOWNTO 0) := X"01200004";
  CONSTANT ESM_AL_OP          : STD_LOGIC_VECTOR(31 DOWNTO 0) := X"01200008";
  CONSTANT CMD_SDO_WRITE      : STD_LOGIC_VECTOR(31 DOWNTO 0) := X"02200100";
  CONSTANT SDO_FILE_RESERVED  : STD_LOGIC_VECTOR(31 DOWNTO 0) := X"07700000";
  CONSTANT SDO_FPGA_FW_INFO   : STD_LOGIC_VECTOR(31 DOWNTO 0) := X"07700001";
  CONSTANT SDO_EEPROM         : STD_LOGIC_VECTOR(31 DOWNTO 0) := X"07700002";
  CONSTANT SDO_FLASH          : STD_LOGIC_VECTOR(31 DOWNTO 0) := X"07700004";
  CONSTANT SDO_AL_CFG_DATA    : STD_LOGIC_VECTOR(31 DOWNTO 0) := X"07700005";
  TYPE CFG_DATA_ARRAY_TYPE IS ARRAY(0 TO 17) of STD_LOGIC_VECTOR(31 DOWNTO 0);
  CONSTANT CFG_DATA_ARRAY     : CFG_DATA_ARRAY_TYPE := (
                                X"16100003",
										  X"16120000",
										  X"161401AE",
										  X"161601A4",
										  X"161800F1",
										  X"161A0003",
										  X"161C0109",
										  X"161E00D6",
										  X"16200001",
										  X"16220001",
										  X"1624012C",
										  X"1626012C",
										  X"1628012C",
										  X"162A012C",
										  X"162C012C",
										  X"162E012C",
										  X"163003E8", -- 1000
										  X"1632189C"  -- 6300
										  );
  CONSTANT CMD_PROCESS_OUTPUT : STD_LOGIC_VECTOR(31 DOWNTO 0) := X"02200400";
  TYPE RUN_DATA_ARRAY_TYPE IS ARRAY(0 TO 19) of STD_LOGIC_VECTOR(31 DOWNTO 0);
  CONSTANT RUN_DATA_ARRAY     : RUN_DATA_ARRAY_TYPE := (
                                X"11008000",
										  X"11020005", -- clear RefSeq error every time
										  X"11040003",
										  X"11060009",
										  X"11080834",
										  X"110A1000", -- no more than 0x3150, not 0x3138
										  X"110C1800",
										  X"110E2000",
										  X"1110000A",
										  X"11120834",
										  X"11141000",
										  X"11161800",
										  X"11182000",
										  X"111A000B",
										  X"111C0834",
										  X"111E1000",
										  X"11201800",
										  X"11222000",
										  X"11240D8B", -- 430V, dc=0.124023
										  X"112606ED"  -- 220V, dc=0.124023
										  );
  -- receive signals
  SIGNAL recData  : STD_LOGIC_VECTOR(31 DOWNTO 0);
  -- FSL state machine
  TYPE STATE_TYPE IS (INIT_DATA_READ, PREOP_WRITE, PREOP_READ, FWINFO_CMD_WRITE, FWINFO_DATA_READ, CFG_CMD_WRITE, CFG_DATA_WRITE, SAFEOP_WRITE, SAFEOP_READ, OP_WRITE, OP_READ, RUN_CMD_WRITE, RUN_DATA_WRITE, RUN_DATA_READ, IDLE, INIT_WRITE, INIT_READ, RUN_CMD_WRITE_TEST, RUN_DATA_WRITE_TEST, RUN_DATA_READ_TEST);
  SIGNAL FSL_State : STATE_TYPE;
  
  SIGNAL RefHeader0 : STD_LOGIC_VECTOR(31 DOWNTO 0);
	
BEGIN

  FSL_M_Full  <= '0';
  FSL_S_Control <= '0';
  
-------------------------------------------------------------------------------
-- state machine: READ_FSL (4 words) -> WRITE_FSL (2 words) -> READ_FSL ->...
-------------------------------------------------------------------------------  
fsl_read_write: PROCESS(FSL_Clk, FSL_Rst)
BEGIN
  IF (FSL_Rst = '1') THEN
    writeNum         <= 0;
    readNum          <= 0;
    FSL_S_Data       <= (OTHERS => '0');
    FSL_S_Exists     <= '0';
    recData          <= (OTHERS => '0');
    FSL_State        <= INIT_DATA_READ;
	 RefHeader0       <= RUN_DATA_ARRAY(0);
  ELSIF (FSL_Clk'event AND FSL_Clk = '1') THEN
  
    CASE FSL_State IS

-------------------------------------------------------------------------------
-- state machine:	Check FSL Communication
-------------------------------------------------------------------------------  

      -- read 4 words from FSL
      WHEN INIT_DATA_READ =>
        FSL_S_Exists <= '0';
        IF (FSL_M_Write = '1') THEN
          CASE readNum IS
            WHEN 0 =>
              recData      <= FSL_M_Data;
              readNum      <= readNum + 1;
            WHEN 1 =>
              recData      <= FSL_M_Data;
              readNum      <= readNum + 1;
            WHEN 2 =>
              recData      <= FSL_M_Data;
              readNum      <= readNum + 1;
            WHEN 3 =>
              recData      <= FSL_M_Data;
              readNum      <= 0;
              FSL_State    <= PREOP_WRITE;
            WHEN OTHERS =>
              NULL;
          END CASE;
        END IF;

-------------------------------------------------------------------------------
-- state machine:	Check State Machine
-------------------------------------------------------------------------------  

      -- write 2 words (commands) to FSL
      WHEN INIT_WRITE =>
        CASE writeNum IS
          WHEN 0 =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
				  writeNum     <= writeNum + 1;
				ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= CMD_AL_CONTROL;
            END IF;
          WHEN 1 =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
              writeNum     <= 0;
              FSL_State    <= INIT_READ;            
            ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= ESM_AL_INIT;
            END IF;
          WHEN OTHERS =>
            NULL;
        END CASE;

      -- read 2 words (commands) from FSL
      WHEN INIT_READ =>
        FSL_S_Exists <= '0';
        IF (FSL_M_Write = '1') THEN
          CASE readNum IS
            WHEN 0 =>
              recData      <= FSL_M_Data;
              readNum      <= readNum + 1;
            WHEN 1 =>
              recData      <= FSL_M_Data;
              readNum      <= 0;
              FSL_State    <= PREOP_WRITE;
            WHEN OTHERS =>
              NULL;
          END CASE;
        END IF;

      -- write 2 words (commands) to FSL
      WHEN PREOP_WRITE =>
        CASE writeNum IS
          WHEN 0 =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
				  writeNum     <= writeNum + 1;
				ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= CMD_AL_CONTROL;
            END IF;
          WHEN 1 =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
              writeNum     <= 0;
              FSL_State    <= PREOP_READ;            
            ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= ESM_AL_PREOP;
            END IF;
          WHEN OTHERS =>
            NULL;
        END CASE;

      -- read 2 words (commands) from FSL
      WHEN PREOP_READ =>
        FSL_S_Exists <= '0';
        IF (FSL_M_Write = '1') THEN
          CASE readNum IS
            WHEN 0 =>
              recData      <= FSL_M_Data;
              readNum      <= readNum + 1;
            WHEN 1 =>
              recData      <= FSL_M_Data;
              readNum      <= 0;
              FSL_State    <= CFG_CMD_WRITE; -- FWINFO_CMD_WRITE; 
            WHEN OTHERS =>
              NULL;
          END CASE;
        END IF;

--      -- write 2 words (commands) to FSL
--      WHEN SAFEOP_WRITE =>
--        CASE writeNum IS
--          WHEN 0 =>
--            IF (FSL_S_Read = '1') THEN
--				  FSL_S_Exists <= '0';
--				  writeNum     <= writeNum + 1;
--				ELSE
--              FSL_S_Exists <= '1';
--              FSL_S_Data   <= CMD_AL_CONTROL;
--            END IF;
--          WHEN 1 =>
--            IF (FSL_S_Read = '1') THEN
--				  FSL_S_Exists <= '0';
--              writeNum     <= 0;
--              FSL_State    <= SAFEOP_READ;            
--            ELSE
--              FSL_S_Exists <= '1';
--              FSL_S_Data   <= ESM_AL_SAFEOP;
--            END IF;
--          WHEN OTHERS =>
--            NULL;
--        END CASE;
--
--      -- read 2 words £¨commands£© from FSL
--      WHEN SAFEOP_READ =>
--        FSL_S_Exists <= '0';
--        IF (FSL_M_Write = '1') THEN
--          CASE readNum IS
--            WHEN 0 =>
--              recData      <= FSL_M_Data;
--              readNum      <= readNum + 1;
--            WHEN 1 =>
--              recData      <= FSL_M_Data;
--              readNum      <= 0;
--              FSL_State    <= OP_WRITE; -- RUN_CMD_WRITE;
--            WHEN OTHERS =>
--              NULL;
--          END CASE;
--        END IF;

      -- write 2 words (commands) to FSL
      WHEN OP_WRITE =>
        CASE writeNum IS
          WHEN 0 =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
				  writeNum     <= writeNum + 1;
				ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= CMD_AL_CONTROL;
            END IF;
          WHEN 1 =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
              writeNum     <= 0;
              FSL_State    <= OP_READ;            
            ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= ESM_AL_OP;
            END IF;
          WHEN OTHERS =>
            NULL;
        END CASE;

      -- read 2 words £¨commands£© from FSL
      WHEN OP_READ =>
        FSL_S_Exists <= '0';
        IF (FSL_M_Write = '1') THEN
          CASE readNum IS
            WHEN 0 =>
              recData      <= FSL_M_Data;
              readNum      <= readNum + 1;
            WHEN 1 =>
              recData      <= FSL_M_Data;
              readNum      <= 0;
              FSL_State    <= RUN_CMD_WRITE;
            WHEN OTHERS =>
              NULL;
          END CASE;
        END IF;

-------------------------------------------------------------------------------
-- state machine:	Upload Firmware Info
-------------------------------------------------------------------------------  

      -- write 2 fw info words (commands) to FSL
      WHEN FWINFO_CMD_WRITE =>
        CASE writeNum IS
          WHEN 0 =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
				  writeNum     <= writeNum + 1;
				ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= CMD_SDO_WRITE;
            END IF;
          WHEN 1 =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
              writeNum     <= 0;
              FSL_State    <= FWINFO_DATA_READ;            
            ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= SDO_FPGA_FW_INFO;
            END IF;
          WHEN OTHERS =>
            NULL;
        END CASE;

      -- read 7 fw info data array from FSL
      WHEN FWINFO_DATA_READ =>
        FSL_S_Exists <= '0';
        IF (FSL_M_Write = '1') THEN
          CASE readNum IS
            WHEN 6 =>
              recData      <= FSL_M_Data;
              readNum      <= 0;
              FSL_State    <= CFG_CMD_WRITE;
            WHEN OTHERS =>
              recData      <= FSL_M_Data;
              readNum      <= readNum + 1;
          END CASE;
        END IF;

-------------------------------------------------------------------------------
-- state machine:	Download Configuration Data
-------------------------------------------------------------------------------  

      -- write 2 config words (commands) to FSL
      WHEN CFG_CMD_WRITE =>
        CASE writeNum IS
          WHEN 0 =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
				  writeNum     <= writeNum + 1;
				ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= CMD_SDO_WRITE;
            END IF;
          WHEN 1 =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
              writeNum     <= 0;
              FSL_State    <= CFG_DATA_WRITE;            
            ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= SDO_AL_CFG_DATA;
            END IF;
          WHEN OTHERS =>
            NULL;
        END CASE;

      -- write 18 config data array to FSL
      WHEN CFG_DATA_WRITE =>
        CASE writeNum IS
          WHEN 17 =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
              writeNum     <= 0;
              FSL_State    <= RUN_CMD_WRITE_TEST; -- SAFEOP_WRITE;            
            ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= CFG_DATA_ARRAY(writeNum);
            END IF;
          WHEN OTHERS =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
				  writeNum     <= writeNum + 1;
				ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= CFG_DATA_ARRAY(writeNum);
            END IF;
        END CASE;

-------------------------------------------------------------------------------
-- state machine:	Verify Process Data and Feedback Data
-------------------------------------------------------------------------------  

      -- write 1 process word (command) to FSL
      WHEN RUN_CMD_WRITE_TEST =>
        CASE writeNum IS
          WHEN 0 =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
              writeNum     <= 0;
              FSL_State    <= RUN_DATA_WRITE_TEST;            
            ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= CMD_PROCESS_OUTPUT;
            END IF;
          WHEN OTHERS =>
            NULL;
        END CASE;

      -- write 20 process data array to FSL
      WHEN RUN_DATA_WRITE_TEST =>
        CASE writeNum IS
          WHEN 19 =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
              writeNum     <= 0;
              FSL_State    <= RUN_DATA_READ_TEST;            
            ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= RUN_DATA_ARRAY(writeNum);
            END IF;
			 WHEN 0 =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
				  writeNum     <= writeNum + 1;
  				  RefHeader0   <= RefHeader0 + X"100";
				ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= RefHeader0;
--              FSL_S_Data   <= RUN_DATA_ARRAY(writeNum);
            END IF;
          WHEN OTHERS =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
				  writeNum     <= writeNum + 1;
				ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= RUN_DATA_ARRAY(writeNum);
            END IF;
        END CASE;

      -- read 20 process data array from FSL
      WHEN RUN_DATA_READ_TEST =>
        FSL_S_Exists <= '0';
        IF (FSL_M_Write = '1') THEN
          CASE readNum IS
            WHEN 19 =>
              recData      <= FSL_M_Data;
              readNum      <= 0;
              FSL_State    <= OP_WRITE;
            WHEN OTHERS =>
              recData      <= FSL_M_Data;
              readNum      <= readNum + 1;
          END CASE;
        END IF;


-------------------------------------------------------------------------------
-- state machine:	Verify Process Data and Feedback Data
-------------------------------------------------------------------------------  

      -- write 1 process word (command) to FSL
      WHEN RUN_CMD_WRITE =>
        CASE writeNum IS
          WHEN 0 =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
              writeNum     <= 0;
              FSL_State    <= RUN_DATA_WRITE;            
            ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= CMD_PROCESS_OUTPUT;
            END IF;
          WHEN OTHERS =>
            NULL;
        END CASE;

      -- write 20 process data array to FSL
      WHEN RUN_DATA_WRITE =>
        CASE writeNum IS
          WHEN 19 =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
              writeNum     <= 0;
              FSL_State    <= RUN_DATA_READ;            
            ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= RUN_DATA_ARRAY(writeNum);
            END IF;
			 WHEN 0 =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
				  writeNum     <= writeNum + 1;
  				  RefHeader0   <= RefHeader0 + X"100";
				ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= RefHeader0;
--              FSL_S_Data   <= RUN_DATA_ARRAY(writeNum);
            END IF;
          WHEN OTHERS =>
            IF (FSL_S_Read = '1') THEN
				  FSL_S_Exists <= '0';
				  writeNum     <= writeNum + 1;
				ELSE
              FSL_S_Exists <= '1';
              FSL_S_Data   <= RUN_DATA_ARRAY(writeNum);
            END IF;
        END CASE;

      -- read 20 process data array from FSL
      WHEN RUN_DATA_READ =>
        FSL_S_Exists <= '0';
        IF (FSL_M_Write = '1') THEN
          CASE readNum IS
            WHEN 19 =>
              recData      <= FSL_M_Data;
              readNum      <= 0;
              FSL_State    <= RUN_CMD_WRITE;
            WHEN OTHERS =>
              recData      <= FSL_M_Data;
              readNum      <= readNum + 1;
          END CASE;
        END IF;

-------------------------------------------------------------------------------
-- state machine:	others
-------------------------------------------------------------------------------  

      WHEN OTHERS =>
        NULL;

    END CASE;
  END IF;
END PROCESS;

END BEHAVIORAL;

