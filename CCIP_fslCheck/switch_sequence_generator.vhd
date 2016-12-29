-- (c) Copyright 2008 ABB
--
-- The information contained in this document has to be kept strictly
-- confidential. Any unauthorised use, reproduction, distribution, 
-- or disclosure to third parties is strictly forbidden. 
-- ABB reserves all rights regarding Intellectual Property Rights
-- **************************************************************************************
-- File information
-- Document number: 		
-- Title:               switch sequence generator
-- File name:           switch_sequence_generator.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:		0.02
-- Prepared by:		SEROP/PRCB 
-- Status:		In progress
-- Date:		2009-02-24
-- **************************************************************************************
-- Related files:
--
-- **************************************************************************************
-- Functional description:
-- Creates both the pwm sequence for the top and bottom IGBT's out of the ideal pwm
-- where a minimum pulse width is added as well as the deadband generation.
--
-- **************************************************************************************
-- 0.02: 090224 - SEROP/PRCB Björn Nyqvist
-- * C_PWM_DEAD_BAND_TICKS is removed since the configurable "deadTimeInverter"
-- vector is now used.
-- * Cosmetic updates
-- **************************************************************************************	

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;
USE ieee.std_logic_arith.ALL;

ENTITY switch_sequence_generator IS
  GENERIC (
    C_CLK_FREQ               : INTEGER RANGE 10_000_000 TO 130_000_000 := 100_000_000;
    C_PWM_UPDATE_RATE_US     : INTEGER RANGE 63 TO 126                 := 126;  -- PWM update rate in microseconds 
    C_PWM_MIN_PULSE_WIDTH_US : INTEGER RANGE 3 TO 6                    := 5  -- PWM min pulse width time in microseconds 
    );

  PORT (
    Clk              : IN  STD_LOGIC;
    Resetn           : IN  STD_LOGIC;    
    Run              : IN  STD_LOGIC;
    Pwm_cnt          : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
    Switch_time      : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
    Pwm_max_cnt      : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
    Pwm_top          : OUT STD_LOGIC;
    Pwm_bottom       : OUT STD_LOGIC;
    deadTimeInverter : IN  STD_LOGIC_VECTOR(11 DOWNTO 0)
    );
END;

ARCHITECTURE rtl OF switch_sequence_generator IS
  
  CONSTANT PWM_MIN_PULSE : STD_LOGIC_VECTOR(11 DOWNTO 0) := conv_std_logic_vector((C_CLK_FREQ/1000000)*C_PWM_MIN_PULSE_WIDTH_US,12);
  
  SIGNAL pwm_ideal_pos_flank            : STD_LOGIC;  -- '1' when pos flank detected
  SIGNAL pwm_ideal_neg_flank            : STD_LOGIC;  -- '1' when neg flank detected 
  SIGNAL pwm_ideal                      : STD_LOGIC;
  SIGNAL pwm_ideal_d                    : STD_LOGIC;  
  SIGNAL pwm_min_pulse_top              : STD_LOGIC;
  SIGNAL pwm_min_pulse_top_d            : STD_LOGIC;
  SIGNAL pwm_min_pulse_bottom           : STD_LOGIC;
  SIGNAL pwm_min_pulse_bottom_d         : STD_LOGIC;
  SIGNAL pwm_min_pulse_width_cnt        : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL pwm_min_pulse_top_pos_flank    : STD_LOGIC;
  SIGNAL pwm_min_pulse_bottom_pos_flank : STD_LOGIC;
  SIGNAL pwm_deadtime_cnt               : STD_LOGIC_VECTOR(11 DOWNTO 0);

BEGIN

  -- Purpose: This process creates an ideal pwm used as reference.
  Ideal_pwm_signal :
  PROCESS(Clk, Resetn)
  BEGIN
    IF (Resetn = '0') THEN
      pwm_ideal <= '0';
    ELSIF (Clk'event AND Clk = '1') THEN
      IF (Run = '1') THEN
        IF (Pwm_cnt > 0) THEN
          IF (Switch_time = Pwm_max_cnt) THEN
            -- exception to keep signal always low
            pwm_ideal <= '0';
          ELSIF (Switch_time = 0) THEN
            -- exception to keep signal always high
            pwm_ideal <= '1';
          ELSIF (Pwm_cnt >= Switch_time) THEN
            pwm_ideal <= '1';
          ELSE
            pwm_ideal <= '0';
          END IF;
        END IF;
      ELSE
        pwm_ideal <= '0';
      END IF;         
    END IF;   
  END PROCESS Ideal_pwm_signal;

  Delay_pwm_ideal :
  PROCESS(Clk, Resetn)
  BEGIN
    IF (Resetn = '0') THEN
      pwm_ideal_d   <= '0';
    ELSIF (Clk'event AND Clk = '1') THEN
      IF (Run = '1') THEN
        pwm_ideal_d <= pwm_ideal;
      ELSE
        pwm_ideal_d <= '0';
      END IF;
    END IF;
  END PROCESS Delay_pwm_ideal;

  -- Flank detection of pwm_ideal
  pwm_ideal_pos_flank <= '1' WHEN (pwm_ideal_d = '0' AND pwm_ideal = '1') ELSE '0';
  pwm_ideal_neg_flank <= '1' WHEN (pwm_ideal_d = '1' AND pwm_ideal = '0') ELSE '0';

  -- Purpose: This process creates both the pwm sequence for the top and bottom IGBT's
  -- out of the ideal pwm where a minimum pulse width is added.
  Min_pulse_width_extension :
  PROCESS(Clk, Resetn)                  
  BEGIN
    IF (Resetn = '0') THEN
      pwm_min_pulse_top       <= '0';
      pwm_min_pulse_bottom    <= '0';
      pwm_min_pulse_width_cnt <= (OTHERS => '0');
    ELSIF (Clk'event AND Clk = '1') THEN
      IF (Run = '1') THEN
        IF (pwm_min_pulse_width_cnt = (PWM_MIN_PULSE + deadTimeInverter - 1)) THEN
          -- + deadband because of later adjustement when delay with deadband in deadtime generator
          IF (pwm_ideal_pos_flank = '1') THEN
            pwm_min_pulse_width_cnt <= (OTHERS => '0');
            pwm_min_pulse_top       <= '1';
            pwm_min_pulse_bottom    <= '0';
          ELSIF (pwm_ideal_neg_flank = '1') THEN
            pwm_min_pulse_width_cnt <= (OTHERS => '0');
            pwm_min_pulse_top       <= '0';
            pwm_min_pulse_bottom    <= '1';
          ELSE
            pwm_min_pulse_top    <= pwm_ideal;
            pwm_min_pulse_bottom <= NOT pwm_ideal;
          END IF;
        ELSE
          pwm_min_pulse_width_cnt <= pwm_min_pulse_width_cnt + 1;
        END IF;
      ELSE
        pwm_min_pulse_top       <= '0';
        pwm_min_pulse_bottom    <= '0';
        pwm_min_pulse_width_cnt <= (OTHERS => '0');
      END IF;
    END IF;
  END PROCESS Min_pulse_width_extension;

  Delay_pwm_min_pulse :
  PROCESS(Clk, Resetn)
  BEGIN
    IF (Resetn = '0') THEN
      pwm_min_pulse_top_d    <= '0';
      pwm_min_pulse_bottom_d <= '0';
    ELSIF (Clk'event AND Clk = '1') THEN
      IF (Run = '1') THEN
        pwm_min_pulse_top_d    <= pwm_min_pulse_top;
        pwm_min_pulse_bottom_d <= pwm_min_pulse_bottom;
      ELSE
        pwm_min_pulse_top_d    <= '0';
        pwm_min_pulse_bottom_d <= '0';
      end if;
    end if;
  END PROCESS Delay_pwm_min_pulse;

  -- Pos flank detection of min width pulses
  pwm_min_pulse_top_pos_flank    <= '1' WHEN (pwm_min_pulse_top_d = '0' AND pwm_min_pulse_top = '1')       ELSE '0';
  pwm_min_pulse_bottom_pos_flank <= '1' WHEN (pwm_min_pulse_bottom_d = '0' AND pwm_min_pulse_bottom = '1') ELSE '0';

  Deadtime_generator :
  PROCESS(Clk, Resetn)
  BEGIN
    IF (Resetn = '0') THEN
      pwm_top <= '0';
      pwm_bottom <= '0';
      pwm_deadtime_cnt <= (OTHERS => '0');
    ELSIF (Clk'event AND Clk = '1') THEN
      IF (Run = '1') THEN
        IF (pwm_deadtime_cnt = (deadTimeInverter - 1)) THEN
          IF (pwm_min_pulse_top_pos_flank = '1') THEN
            -- pwm top is to be activated after the deadtime
            pwm_deadtime_cnt <= (OTHERS => '0');
            pwm_top    <= '0';
            pwm_bottom <= '0';    -- bottom can be switched immediately
          ELSIF (pwm_min_pulse_bottom_pos_flank = '1') THEN
            -- pwm bottom is to be activated after the deadtime            
            pwm_deadtime_cnt <= (OTHERS => '0');
            pwm_top    <= '0';    -- top can be switched immediately
            pwm_bottom <= '0';
          ELSE
            pwm_top    <= pwm_min_pulse_top;
            pwm_bottom <= pwm_min_pulse_bottom;
          END IF;
        ELSE
          pwm_deadtime_cnt <= pwm_deadtime_cnt + 1;
        END IF;
      ELSE
        pwm_top <= '0';
        pwm_bottom <= '0';
        pwm_deadtime_cnt <= (OTHERS => '0');
      END IF;
    END IF;
  END PROCESS Deadtime_generator;

END rtl; 	    
