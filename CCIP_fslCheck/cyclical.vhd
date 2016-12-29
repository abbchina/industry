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
-- Title:               Cyclical state machine entity
-- File name:           duf_sc/cyclical.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:            0.05
-- Prepared by:         SEROP/Magnus Tysell
-- Status:              Edited
-- Date:                2009-09-29
-- **************************************************************************************
-- Related files:       duf_sc/SlaveController_top.vhd
--                      duf_sc/comm_dpm_controller.vhd
-- **************************************************************************************
-- Functional description:
-- 
-- This module copies cyclic process (Robocat) data between the COMM DPM and SC DPM and 
-- signals "data_updated" to the PU-logic when the copying is done. The data_updated 
-- signal is pulsed when all the output process data have been transferred to the SC DPM 
-- under the condition that the frame did not contain any errors. When the fdb_updated 
-- signal is pulsed by the PU-logic it means that the PU-logic has copied the process 
-- feedback data to the SC DPM and this module starts to copy the data to the COMM DPM.
-- The module is activated by pulsing the start signal and the module flags for the 
-- completion by pulsing the done signal.
-- 
-- **************************************************************************************
-- 0.2 2008-06-30 Björn Nyqvist: "data_updated" has now a reset value +
-- cosmetic updates.
-- **************************************************************************************
-- 0.3 2008-12-11 Magnus Tysell: Removed sc_status_reg and added validFrame and commFailure.
-- Updated Idle state.
-- **************************************************************************************
-- 0.4 2009-04-03 Magnus Tysell
-- * Reviewed and comments added.
-- * Number of words to copy changed from 16 to 19. The entire PU-related data area is 
--   being copied, including the pwmDelayTime data for each node.
-- * Changed signal names: 
--    - slave_output_nr_words change  -> NR_OF_REFERENCE_WORDS
--    - slave_input_nr_words          -> NR_OF_FEEDBACK_WORDS 
--    - slave_output_data_start_addr  -> COMM_DPM_REFERENCE_START_ADDR 
--    - slave_input_data_start_addr   -> COMM_DPM_FEEDBACK_START_ADDR
--    - dpm_output_data_start_addr    -> SC_DPM_REFERENCE_START_ADDR
--    - dpm_input_data_start_addr     -> SC_DPM_FEEDBACK_START_ADDR 
-- * Signals removed: 
--    - slave_output_data_map_offset  (always increment by '1' instead, copying the whole 
--      PU-part of Robocat.)
--    - slave_input_data_map_offset   (always increment by '1' instead, copying the whole 
--      PU-part of Robocat.)
--    - TYPE integer_array IS ARRAY (INTEGER RANGE <>) OF INTEGER;
--    - dpm_output_data_addr
--    - dpm_input_data_addr  
-- **************************************************************************************
-- Revision 0.05 - 090929, CNABB/Ye-Ye Zhang
-- Changed the order of ports.
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY cyclical IS
  PORT(
    reset_n        : IN  STD_LOGIC;
    clk            : IN  STD_LOGIC;
    -- DPM signals
	 comm_dpm_web   : OUT STD_LOGIC;
    comm_dpm_dinb  : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    comm_dpm_doutb : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
    comm_dpm_addrb : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    ctrl_dpm       : OUT STD_LOGIC;
    dpm_addra      : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    dpm_dina       : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    dpm_douta      : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
    dpm_wea        : OUT STD_LOGIC;
    -- SC internal signals
    start          : IN  STD_LOGIC;
    done           : OUT STD_LOGIC;
    validFrame     : IN  STD_LOGIC;
	 -- PU internal signals
	 data_updated   : OUT STD_LOGIC;
    pu_fdb_updated : IN  STD_LOGIC;
    commFailure    : IN  STD_LOGIC
    );
END cyclical;

ARCHITECTURE rtl OF cyclical IS

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

  -- Reference: (from commDPM to scDPM)
  CONSTANT COMM_DPM_REFERENCE_START_ADDR  : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0006";       -- Start address for PU-logic related reference data.
  CONSTANT SC_DPM_REFERENCE_START_ADDR    : STD_LOGIC_VECTOR(5 DOWNTO 0)  := B"00_0000";    -- Start address for PU-logic related reference data.
  CONSTANT NR_OF_REFERENCE_WORDS          : STD_LOGIC_VECTOR(4 downto 0)  := B"1_0011";         
  -- Feedback: (from scDPM to commDPM)
  CONSTANT COMM_DPM_FEEDBACK_START_ADDR   : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0019";       -- Start address for PU-logic related feedback data.
  CONSTANT SC_DPM_FEEDBACK_START_ADDR     : STD_LOGIC_VECTOR(5 DOWNTO 0)  := B"100000";     -- Start address for PU-logic related feedback data.
  CONSTANT NR_OF_FEEDBACK_WORDS           : STD_LOGIC_VECTOR(4 downto 0)  := B"1_0011";  
  -- Cyclical state machine
  TYPE CYCL_STATE_TYPE IS (Idle, Read_Slave, Write_DPM, Check_Missing_Frame, Read_DPM, Write_Slave);
  SIGNAL cycl_state : CYCL_STATE_TYPE;
  -- DPM Controller signals
  SIGNAL cdc_ctrl_register : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL cdc_read_data     : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL cdc_write_data    : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL cdc_addr          : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL cdc_done          : STD_LOGIC;
  -- Cyclical related signals
  SIGNAL copyPtr : STD_LOGIC_VECTOR(4 DOWNTO 0);
  SIGNAL commDPMDataOut : STD_LOGIC_VECTOR(15 DOWNTO 0);

BEGIN

-------------------------------------------------------------------------------
-- Cyclical state machine:
-------------------------------------------------------------------------------
  cyclical_ctrl : PROCESS (reset_n, clk) IS
  BEGIN
    IF reset_n = '0' THEN
      commDPMDataOut    <= (OTHERS => '0');
      copyPtr           <= (OTHERS => '0');
      ctrl_dpm          <= '0';
      cdc_ctrl_register <= (OTHERS => '0');
      cdc_write_data    <= (OTHERS => '0');
      cdc_addr          <= (OTHERS => '0');
      done              <= '0';
      dpm_addra         <= (OTHERS => '0');
      dpm_dina          <= (OTHERS => '0');
      dpm_wea           <= '0';
      cycl_state        <= Idle;
      data_updated      <= '0';
    ELSIF clk'event AND clk = '1' THEN
      
      CASE cycl_state IS
      
        -- Waiting for event. 
        WHEN Idle =>
          dpm_wea      <= '0';
          data_updated <= '0';
          done         <= '0';
          IF start = '1' THEN
            IF commFailure = '0' THEN
              -- Starting to copy the data from commDPM to scDPM.
              copyPtr <= (OTHERS => '0');
              cycl_state  <= Read_Slave;              
             ELSE
              done  <= '1';
             END IF;
          ELSIF pu_fdb_updated = '1' THEN
            -- PU_top signals "feedback data available in SC_DPM" 
            -- Starting data copy from SC_DPM to COMM_DPM.
            copyPtr <= (OTHERS => '0');
            cycl_state <= Read_DPM;	
          END IF;

        WHEN Read_Slave =>
          -- Reads a word from the COMM_DPM
          dpm_wea <= '0';
          IF cdc_done = '1' THEN
            ctrl_dpm              <= '0';
            cdc_ctrl_register(4)  <= '0';
            commDPMDataOut        <= cdc_read_data;
            cycl_state  <= Write_DPM;
          ELSE
            -- Start to read data from COMM_DPM.
            cdc_addr <= COMM_DPM_REFERENCE_START_ADDR + copyPtr;
            ctrl_dpm <= '1';
            cdc_ctrl_register(4) <= '1';
            cycl_state <= Read_Slave;
          END IF;
          
        WHEN Write_DPM =>
          --Writes the last read word, from the communication DPM, to the PU DPM
	       --if this was to be moved into Read_Slave 2 cycles could be saved
          dpm_addra     <= SC_DPM_REFERENCE_START_ADDR + copyPtr;
          dpm_dina      <= commDPMDataOut;
          dpm_wea       <= '1';						
          IF copyPtr = NR_OF_REFERENCE_WORDS THEN
            copyPtr <= (OTHERS => '0');
            cycl_state  <= Check_Missing_Frame;              
          ELSE
            copyPtr <= copyPtr + '1';
            cycl_state  <= Read_Slave;
          END IF;

        WHEN Check_Missing_Frame =>
          IF validFrame = '1' THEN
            -- Will only signal "new data available" to PU_top the received frame was valid.
            data_updated <= '1';
          END IF;
          cycl_state     <= Idle;


        WHEN Read_DPM =>
          -- Reads a word from the SC_DPM.  
          dpm_addra  <= SC_DPM_FEEDBACK_START_ADDR + copyPtr;                            
          cycl_state <= Write_Slave;
          
        WHEN Write_Slave =>
          -- Writes data to the COMM_DPM.
          IF cdc_done = '1' THEN
            ctrl_dpm <= '0';
            cdc_ctrl_register(5) <= '0';
            IF copyPtr = NR_OF_FEEDBACK_WORDS THEN
              -- All data written to COMM_DPM, go to Idle. 
              copyPtr <=(OTHERS => '0');
              done        <= '1';  -- Indicate to SlaveCtrl that cyclical process is finalized.
              cycl_state  <= Idle;
            ELSE
              copyPtr <= copyPtr + '1';
              cycl_state  <= Read_DPM;
            END IF;
          ELSE
            cdc_addr        <= COMM_DPM_FEEDBACK_START_ADDR + copyPtr;
            cdc_write_data  <= dpm_douta;
            ctrl_dpm        <= '1';
            cdc_ctrl_register(5) <= '1';
            cycl_state      <= Write_Slave;
          END IF;

      END CASE;
    END IF;
  END PROCESS cyclical_ctrl;

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

