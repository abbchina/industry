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
--	Title:					Supervision entity in Slave Controller Module
--	File name:				duf_sc/supervision.vhd
-- **************************************************************************************
-- Revision information
-- Revision index: 		0
-- Revision:				0.04
--	Prepared by:			SECRC/MRA Erik Nilsson
-- Status:					Edited
-- Date:						2009-09-27
-- **************************************************************************************
-- Related files:       duf_sc/SlaveController_top.vhd
-- **************************************************************************************
-- Functional description:
-- 
-- This block handles the supervision of possible frame errors. It activates the 
-- comm_failure signal when the number of consecutive frame errors exceeds MaxLostFrames.
-- The comm_failure signal is cleared by a positive edge on the ClearCommError signal, 
-- which is set by external command.
-- It also generates a pulse on the comm_error signal when the watchdog triggers. The 
-- watchdog is kicked by the irq_synch_pulse signal.
-- 
-- **************************************************************************************
-- changes:
-- Revision 0.2 - 081130, SEROP/Magnus Tysell
-- * Changes for new robocat. Signals from cfgUnit added; maxLostFrames and wd_signals.
-- * Removed ctrl_reg, replaced with enable signal and framLostCounter.
-- * Integrated the watchdog process in this file.
-- * watchdog enabled when periodicStarted = '1'.
-- **************************************************************************************
-- Revision 0.3 - 080401, SEROP/Magnus Tysell
-- * comm_failure reset only when resetCommFailure bit in Robocat is received. Earlier 
-- it was reset also when the number of lostframes was lower than maxLostFrames.
-- **************************************************************************************
-- Revision 0.04 - 090927, CNABB/Ye-Ye Zhang
-- Removed pdi marks. 
-- * Replace pdi_Irq with irq_synch_pulse.
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY supervision IS
  PORT (
    reset_n            : IN  STD_LOGIC;
    clk                : IN  STD_LOGIC;
    -- IRQ signals
    irq_synch_pulse    : IN  STD_LOGIC;
    -- SC internal signals
    comm_error         : OUT STD_LOGIC;
    comm_failure       : OUT STD_LOGIC;
    lostFrames         : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
    resetCommFailure   : IN  STD_LOGIC;
    periodicStarted    : IN  STD_LOGIC;
    -- ConfigUnit signals
    wdtTimeout         : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    wdtTimeoutInterval : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
    maxNoOfLostFrames  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0)
    );
END supervision;

ARCHITECTURE rtl OF supervision IS

  SIGNAL counter   : INTEGER RANGE 0 TO 65535;
  SIGNAL wdTimeout : STD_LOGIC;

BEGIN

  supervision_ctrl: 
  PROCESS (reset_n, clk) IS
  BEGIN
    IF reset_n = '0' THEN
  	  comm_error 	<= '0';
  	  comm_failure 	<= '0';
    ELSIF clk'event AND clk = '1' THEN
      IF wdTimeout = '1' THEN
        -- Generates the comm_error output signal (pulse) which is used in 
        -- slavecontroller when there is a watchdog timeout. 
        IF maxNoOfLostFrames /= 0 THEN		      
          -- Just to be able to run the DSP eval board test. 
          -- WILL DISABLE THE COMM_FAILURE!!!
          comm_error <= '1';
        END IF;
      ELSE
  	    comm_error <= '0';
      END IF;
      IF resetCommFailure = '1' THEN
        -- The communication failure is reset by external command.
        comm_failure <= '0';
      ELSIF lostFrames >= maxNoOfLostFrames THEN 
        --Activate comm_failure when too many frame errors are reported
        IF maxNoOfLostFrames /= 0 THEN		      -- Just to be able to run the DSP eval board test.
          comm_failure <= '1';
        END IF;
      ELSE 
        NULL;
      END IF;
    END IF;
  END PROCESS supervision_ctrl;
	
  -----------------------------------------------------------------------------	
  -- Watchdog process: 
  -- When the periodic communication has started this process will detect if 
  -- there is a lost frame. Counting the ticks from last incomming irq_synch_pulse 
  -- (any type of event) and comparing it with the configured parameters
  -- "wdtTimeoutInterval" and "wdtTimeout". If there is a watchdog timeout, the 
  -- counter is adjusted to compensate for the wdtTimeout".
  -- The watchdog is enabled as long as the periodicStarted signal is set.
  -----------------------------------------------------------------------------
  watchdog_ctrl :
  PROCESS (reset_n, clk) IS
  BEGIN
    IF reset_n = '0' THEN
      wdTimeout     <= '0';
      counter       <= 0;
    ELSIF clk'event AND clk = '1' THEN
      IF periodicStarted = '1' THEN
        --watch dog enabled
        IF irq_synch_pulse = '1' THEN
          --kicked
          counter   <= 1;
          wdTimeout <= '0';
        ELSIF counter = (conv_integer(wdtTimeoutInterval) + conv_integer(wdtTimeout)) THEN
          counter   <= conv_integer(wdtTimeout);
          wdTimeout <= '1';
        ELSE
          wdTimeout <= '0';
          counter   <= counter + 1;
        END IF;
      ELSE
        counter     <= 0;
        wdTimeout   <= '0';
      END IF;
    END IF;
  END PROCESS watchdog_ctrl;
  
END rtl;
