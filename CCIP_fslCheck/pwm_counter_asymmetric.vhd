-- (c) Copyright 2008 ABB
--
-- The information contained in this document has to be kept strictly
-- confidential. Any unauthorised use, reproduction, distribution, 
-- or disclosure to third parties is strictly forbidden. 
-- ABB reserves all rights regarding Intellectual Property Rights
-- **************************************************************************************
-- File information
-- Document number: 		
-- Title:               pwm counter asymmetric
-- File name:           pwm_counter_assymetric.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:		0.03
-- Prepared by:		SEROP/PRCB 
-- Status:		In progress
-- Date:		2009-03-31
-- **************************************************************************************
-- Related files:
--
-- **************************************************************************************
-- Functional description:
-- PWM asymmmetric switching aimed for 4KHz. This block basically verifies that
-- the size of the incoming switch times are within the "pwm update rate", otherwise 
-- the switch times are truncated so they fit into each pwm slot created by Pwm_synch.
--
-- If max frequency needs to be increased, the vector length has to be increased.
--
-- **************************************************************************************
-- 0.02: 090224 - SEROP/PRCB Björn Nyqvist
-- * C_PWM_DEAD_BAND_TICKS is removed since the configurable "deadTimeInverter"
-- vector is now used. However, deadtime not used by this component
-- * Cosmetic updates
-- **************************************************************************************	
-- 0.03: 090331 - SEROP/PRCB Björn Nyqvist
-- * Pwm_synch_n changed name to Pwm_synch since it is not active low.
-- * The process "Rising_edge_synch_pulse" removed due to lack of purpose.
-- * Start removed since it is completely redundant with Stop.
-- * Changed reset state of pwm_cnt direction to "PWM_COUNTER_UP".
-- **************************************************************************************	

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;
USE ieee.std_logic_arith.ALL;

ENTITY pwm_counter_asymmetric IS
  GENERIC (
    C_CLK_FREQ               : INTEGER RANGE 10_000_000 TO 130_000_000 := 100_000_000;
    C_PWM_UPDATE_RATE_US     : INTEGER RANGE 63 TO 126                 := 126;  -- PWM update rate in microseconds 
    C_PWM_MIN_PULSE_WIDTH_US : INTEGER RANGE 3 TO 6                    := 5  -- PWM min pulse width time in microseconds
    );

  PORT (
    Clk          : IN  STD_LOGIC;
    Resetn       : IN  STD_LOGIC;    
    Pwm_synch    : IN  STD_LOGIC;
    Stop         : IN  STD_LOGIC;
    U_switch_in  : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
    V_switch_in  : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
    W_switch_in  : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
    Run          : OUT STD_LOGIC;
    Pwm_cnt      : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    Pwm_max_cnt  : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    U_switch_out : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    V_switch_out : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    W_switch_out : OUT STD_LOGIC_VECTOR(13 DOWNTO 0)
    );
END;

ARCHITECTURE rtl OF pwm_counter_asymmetric IS

  CONSTANT PWM_MAX_COUNT    : STD_LOGIC_VECTOR(13 DOWNTO 0) := conv_std_logic_vector(((C_CLK_FREQ/1000000)*C_PWM_UPDATE_RATE_US), 14);
  CONSTANT PWM_COUNTER_UP   : STD_LOGIC                     := '1';
  CONSTANT PWM_COUNTER_DOWN : STD_LOGIC                     := '0';

  TYPE pwm_state_type IS (idle, run_state);
  SIGNAL pwm_state : pwm_state_type;

  SIGNAL pwm_cnt_i         : STD_LOGIC_VECTOR(13 DOWNTO 0);
  SIGNAL pwm_restart_value : STD_LOGIC;  -- cnt restart select signal, 1 = min
  SIGNAL pwm_switch_en     : STD_LOGIC;  -- enable signal for switch_generator
  SIGNAL pwm_cnt_direction : STD_LOGIC;  -- count up or down, 1 = up, 0 = down

BEGIN

  -- Purpose: Counts the time from the PWM center point which is where the pwm_
  -- synch pulse is asserted. Upon every second pwm_synch, the direction of
  -- the counter is changed.
  Pwm_counter :
  PROCESS(Clk, Resetn)
  BEGIN
    IF (Resetn = '0') THEN
      pwm_cnt_i <= (OTHERS => '0');
      pwm_state <= idle;
      pwm_restart_value <= '0';
      pwm_cnt_direction <= PWM_COUNTER_UP;
      pwm_switch_en <= '0';
    ELSIF (clk'event AND clk = '1') THEN
      CASE pwm_state IS

        WHEN idle =>
          -- Wait until PWM generation is started
          pwm_switch_en <= '0';
          pwm_restart_value <= '0';
          pwm_cnt_direction <= PWM_COUNTER_UP;
          pwm_cnt_i <= (OTHERS => '0');
          IF (Stop = '0' AND Pwm_synch = '1') THEN
            pwm_switch_en <= '1';
            pwm_state <= run_state;
          END IF;

        WHEN run_state =>
          IF (Stop = '1') THEN
            pwm_state <= idle;
          ELSIF (pwm_synch = '1') THEN
            -- PWM switching times are updated
            pwm_switch_en  <= '1';
            IF (pwm_restart_value = '0') THEN
              -- set next counter start value to max and change direction to down
              pwm_restart_value <= '1';
              pwm_cnt_i <= PWM_MAX_COUNT;
              pwm_cnt_direction <= PWM_COUNTER_DOWN;  --must be set if the counter is unsynchronized with the pwm_synch 
            ELSE
              -- set next counter start value to min and change direction to up
              pwm_restart_value <= '0';
              pwm_cnt_i <= (OTHERS => '0');
              pwm_cnt_direction <= PWM_COUNTER_UP;  --must be set if the counter is unsynchronized with the pwm_synch
            END IF;
          ELSE
            pwm_switch_en  <= '0';
            IF pwm_cnt_direction = PWM_COUNTER_UP THEN
              pwm_cnt_i <= pwm_cnt_i + 1;
              IF (pwm_cnt_i = (PWM_MAX_COUNT - 1)) THEN
                --this is to verify that the counter will change direction if synch signal has not been received
                pwm_cnt_direction <= PWM_COUNTER_DOWN;
              END IF;
            ELSE
              pwm_cnt_i <= pwm_cnt_i - 1;
              IF (pwm_cnt_i = 1) THEN
                --this is to verify that the counter will change direction if synch signal has not been received
                pwm_cnt_direction <= PWM_COUNTER_UP;
              END IF;
            END IF;
          END IF;

      END CASE;
    END IF;
  END PROCESS Pwm_counter;

  -- Purpose: Sanity check of the incoming switching times.
  Update_pwm_switch_times :
  PROCESS(Clk, Resetn)
  BEGIN
    IF (Resetn = '0') THEN
      u_switch_out <= (OTHERS => '0');
      v_switch_out <= (OTHERS => '0');
      w_switch_out <= (OTHERS => '0');
    ELSIF (Clk'event AND Clk = '1') THEN
      IF (pwm_switch_en = '1') THEN
        IF (U_switch_in >= PWM_MAX_COUNT) THEN
          -- keep top constant low
          u_switch_out <= PWM_MAX_COUNT;
        ELSE
          -- ideal switch without min pulse width or deadtime
          u_switch_out <= U_switch_in;  
        END IF;

        IF (V_switch_in >= PWM_MAX_COUNT) THEN
          -- keep top constant low
          v_switch_out <= PWM_MAX_COUNT;
        ELSE
          -- ideal switch without min pulse width or deadtime
          v_switch_out <= V_switch_in;  
        END IF;

        IF (W_switch_in >= PWM_MAX_COUNT) THEN
          -- keep top constant low
          w_switch_out <= PWM_MAX_COUNT;
        ELSE
          -- ideal switch without min pulse width or deadtime
          w_switch_out <= W_switch_in;  
        END IF;
      END IF;
    END IF;
  END PROCESS Update_pwm_switch_times;

  Run <= '1' WHEN (pwm_state = run_state) ELSE '0';

-------------------------------------------------------------------------------
-- Continuous assignments 
-------------------------------------------------------------------------------
  Pwm_cnt      <= pwm_cnt_i;
  Pwm_max_cnt  <= PWM_MAX_COUNT;

END rtl;
