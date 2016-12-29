-- (c) Copyright 2008 ABB
--
-- The information contained in this document has to be kept strictly
-- confidential. Any unauthorised use, reproduction, distribution, 
-- or disclosure to third parties is strictly forbidden. 
-- ABB reserves all rights regarding Intellectual Property Rights
-- **************************************************************************************
-- File information
-- Document number: 		
-- Title:               PWM
-- File name:           PWM_4K8K.vhd
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
-- Top level of the PWM generation just mapping blocks together.
-- If max frequency needs to be increased, the vector length has to be increased.
--
-- **************************************************************************************
-- 0.02: 090224 - SEROP/PRCB Björn Nyqvist
-- * C_PWM_DEAD_BAND_TICKS is removed since the configurable "deadTimeInverter"
-- vector is now used.
-- * Cosmetic updates
-- **************************************************************************************	
-- 0.03: 090331 - SEROP/PRCB Björn Nyqvist
-- * Pwm_synch_n changed name to Pwm_synch since it is not active low.
-- * Start removed since it is completely redundant with Stop
-- **************************************************************************************	
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;
USE ieee.std_logic_arith.ALL;

ENTITY pwm IS  
  GENERIC (
    C_CLK_FREQ               : INTEGER RANGE 10_000_000 TO 130_000_000 := 100_000_000;
    C_PWM_UPDATE_RATE_US     : INTEGER RANGE 63 TO 126                 := 126;  -- PWM frequency in microseconds 
    C_PWM_MIN_PULSE_WIDTH_US : INTEGER RANGE 3 TO 6                    := 5  -- PWM min pulse width time in microseconds
    );
  PORT (
    Clk              : IN  STD_LOGIC;
    Resetn           : IN  STD_LOGIC;    
    Pwm_synch        : IN  STD_LOGIC;
    PWM_ASYM_or_SYM  : IN  STD_LOGIC;   -- PWM_ASYM_or_SYM = 0 (default) which means asymmetric
    Stop             : IN  STD_LOGIC;
    U_switch         : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
    V_switch         : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
    W_switch         : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
    U_pwm_top        : OUT STD_LOGIC;
    V_pwm_top        : OUT STD_LOGIC;
    W_pwm_top        : OUT STD_LOGIC;
    U_pwm_bottom     : OUT STD_LOGIC;
    V_pwm_bottom     : OUT STD_LOGIC;
    W_pwm_bottom     : OUT STD_LOGIC;
    deadTimeInverter : IN  STD_LOGIC_VECTOR(11 DOWNTO 0)
    );
END;

ARCHITECTURE str OF pwm is

  COMPONENT pwm_counter_asymmetric
    GENERIC (
      C_CLK_FREQ               : INTEGER RANGE 10_000_000 TO 130_000_000 := 100_000_000;
      C_PWM_UPDATE_RATE_US     : INTEGER RANGE 63 TO 126                 := 126;  
      C_PWM_MIN_PULSE_WIDTH_US : INTEGER RANGE 3 TO 6                    := 5  
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
      W_switch_out : OUT STD_LOGIC_VECTOR(13 DOWNTO 0));
  END COMPONENT;

  COMPONENT pwm_counter_symmetric
    GENERIC (
      C_CLK_FREQ               : INTEGER RANGE 10_000_000 TO 130_000_000 := 100_000_000;
      C_PWM_UPDATE_RATE_US     : INTEGER RANGE 63 TO 126                 := 126;
      C_PWM_MIN_PULSE_WIDTH_US : INTEGER RANGE 3 TO 6                    := 5  
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
      W_switch_out : OUT STD_LOGIC_VECTOR(13 DOWNTO 0));
  END COMPONENT;

  COMPONENT switch_sequence_generator
    GENERIC (
      C_CLK_FREQ               : INTEGER RANGE 10_000_000 TO 130_000_000 := 100_000_000;
      C_PWM_UPDATE_RATE_US     : INTEGER RANGE 63 TO 126                 := 126;
      C_PWM_MIN_PULSE_WIDTH_US : INTEGER RANGE 3 TO 6                    := 5 
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
  END COMPONENT;

  SIGNAL run_i, run_i_sym, run_i_asym                         : STD_LOGIC;
  SIGNAL pwm_cnt_i, pwm_cnt_i_sym, pwm_cnt_i_asym             : STD_LOGIC_VECTOR(13 DOWNTO 0);
  SIGNAL pwm_max_cnt_i, pwm_max_cnt_i_sym, pwm_max_cnt_i_asym : STD_LOGIC_VECTOR(13 DOWNTO 0);
  SIGNAL u_switch_i, v_switch_i, w_switch_i                   : STD_LOGIC_VECTOR(13 DOWNTO 0);
  SIGNAL u_switch_i_asym, v_switch_i_asym, w_switch_i_asym    : STD_LOGIC_VECTOR(13 DOWNTO 0);
  SIGNAL u_switch_i_sym, v_switch_i_sym, w_switch_i_sym       : STD_LOGIC_VECTOR(13 DOWNTO 0);
  SIGNAL u_pwm_top_i, v_pwm_top_i, w_pwm_top_i                : STD_LOGIC;
  SIGNAL u_pwm_bottom_i, v_pwm_bottom_i, w_pwm_bottom_i       : STD_LOGIC;

BEGIN
   
  u_switch_i    <= u_switch_i_sym    WHEN PWM_ASYM_or_SYM = '1' ELSE u_switch_i_asym;
  v_switch_i    <= v_switch_i_sym    WHEN PWM_ASYM_or_SYM = '1' ELSE v_switch_i_asym;
  w_switch_i    <= w_switch_i_sym    WHEN PWM_ASYM_or_SYM = '1' ELSE w_switch_i_asym;
  run_i         <= run_i_sym         WHEN PWM_ASYM_or_SYM = '1' ELSE run_i_asym;
  pwm_cnt_i     <= pwm_cnt_i_sym     WHEN PWM_ASYM_or_SYM = '1' ELSE pwm_cnt_i_asym;
  pwm_max_cnt_i <= pwm_max_cnt_i_sym WHEN PWM_ASYM_or_SYM = '1' ELSE pwm_max_cnt_i_asym;

  Asymmetric_pwm_counter : pwm_counter_asymmetric
    GENERIC MAP (
      C_CLK_FREQ               => C_CLK_FREQ,
      C_PWM_UPDATE_RATE_US     => C_PWM_UPDATE_RATE_US,
      C_PWM_MIN_PULSE_WIDTH_US => C_PWM_MIN_PULSE_WIDTH_US)
    PORT MAP (
      Clk          => Clk,
      Resetn       => Resetn,
      Pwm_synch    => Pwm_synch,
      Stop         => Stop,
      U_switch_in  => U_switch,
      V_switch_in  => V_switch,
      W_switch_in  => W_switch,
      Run          => run_i_asym,
      Pwm_cnt      => pwm_cnt_i_asym,
      Pwm_max_cnt  => pwm_max_cnt_i_asym,
      U_switch_out => u_switch_i_asym,
      V_switch_out => v_switch_i_asym,
      W_switch_out => w_switch_i_asym
      );

  Symmetric_pwm_counter : pwm_counter_symmetric
    GENERIC MAP (
      C_CLK_FREQ               => C_CLK_FREQ,
      C_PWM_UPDATE_RATE_US     => C_PWM_UPDATE_RATE_US,
      C_PWM_MIN_PULSE_WIDTH_US => C_PWM_MIN_PULSE_WIDTH_US)
    PORT MAP (
      Clk          => Clk,
      Resetn       => Resetn,
      Pwm_synch    => Pwm_synch,
      Stop         => Stop,
      U_switch_in  => U_switch,
      V_switch_in  => V_switch,
      W_switch_in  => W_switch,
      Run          => run_i_sym,
      Pwm_cnt      => pwm_cnt_i_sym,
      Pwm_max_cnt  => pwm_max_cnt_i_sym,
      U_switch_out => u_switch_i_sym,
      V_switch_out => v_switch_i_sym,
      W_switch_out => w_switch_i_sym
      );
	
  U_phase : switch_sequence_generator
    GENERIC MAP (
      C_CLK_FREQ               => C_CLK_FREQ,
      C_PWM_UPDATE_RATE_US     => C_PWM_UPDATE_RATE_US,
      C_PWM_MIN_PULSE_WIDTH_US => C_PWM_MIN_PULSE_WIDTH_US)
    PORT MAP (
      Clk              => Clk,
      Resetn           => Resetn,
      Run              => run_i,
      Pwm_cnt          => pwm_cnt_i,
      Switch_time      => u_switch_i,
      Pwm_max_cnt      => pwm_max_cnt_i,
      Pwm_top          => u_pwm_top_i,
      Pwm_bottom       => u_pwm_bottom_i,
      deadTimeInverter => deadTimeInverter
      );

  V_phase : switch_sequence_generator
    GENERIC MAP (
      C_CLK_FREQ               => C_CLK_FREQ,
      C_PWM_UPDATE_RATE_US     => C_PWM_UPDATE_RATE_US,
      C_PWM_MIN_PULSE_WIDTH_US => C_PWM_MIN_PULSE_WIDTH_US)
    PORT MAP (
      Clk              => Clk,
      Resetn           => Resetn,
      Run              => run_i,
      Pwm_cnt          => pwm_cnt_i,
      Switch_time      => v_switch_i,
      Pwm_max_cnt      => pwm_max_cnt_i,
      Pwm_top          => v_pwm_top_i,
      Pwm_bottom       => v_pwm_bottom_i,
      deadTimeInverter => deadTimeInverter
      );

  W_phase : switch_sequence_generator
    GENERIC MAP (
      C_CLK_FREQ               => C_CLK_FREQ,
      C_PWM_UPDATE_RATE_US     => C_PWM_UPDATE_RATE_US,
      C_PWM_MIN_PULSE_WIDTH_US => C_PWM_MIN_PULSE_WIDTH_US)
    PORT MAP (
      Clk              => Clk,
      Resetn           => Resetn,
      Run              => run_i,
      Pwm_cnt          => pwm_cnt_i,
      Switch_time      => w_switch_i,
      Pwm_max_cnt      => pwm_max_cnt_i,
      Pwm_top          => w_pwm_top_i,
      Pwm_bottom       => w_pwm_bottom_i,
      deadTimeInverter => deadTimeInverter
      );

-------------------------------------------------------------------------------
-- Continuous assignments 
-------------------------------------------------------------------------------
  U_pwm_top    <= u_pwm_top_i;
  U_pwm_bottom <= u_pwm_bottom_i;
  V_pwm_top    <= v_pwm_top_i;
  V_pwm_bottom <= v_pwm_bottom_i;
  W_pwm_top    <= w_pwm_top_i;
  W_pwm_bottom <= w_pwm_bottom_i;
  
END ARCHITECTURE str;
