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
-- Title:               Inverter node top
-- File name:           inverter_node_top_4k8k.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:		1.01
-- Prepared by:		SEROP/PRCB 
-- Status:		In progress
-- Date:		2009-04-06
-- **************************************************************************************
-- Related files:
--
-- **************************************************************************************
-- Functional description:
--
-- **************************************************************************************
-- 0.02: 081209 - SEROP/PRCB Björn Nyqvist
-- Inverter supervision added
-- **************************************************************************************
-- 0.03: 090128 - SEROP/PRCB Björn Nyqvist
-- Inverter undervoltage supervision removed due to AXC is noticed indirectly
-- by the "powerBoardSupplyFailure" feedback status bit.
-- **************************************************************************************
-- 0.04: 090224 - SEROP/PRCB Björn Nyqvist
-- * C_PWM_DEAD_BAND_TICKS is removed since the configurable "deadTimeInverter"
-- vector is now used for each separate inverter. 
-- **************************************************************************************	
-- 0.05: 090331 - SEROP/PRCB Björn Nyqvist
-- * pwmOn_d removed since it is no longer used
-- * Pwm_synch_n changed name to Pwm_synch since it is not active low.
-- * The constant NUMBER_OF_NODES was merged with the generic nrOfNodes to a
--  new generic "NR_OF_NODES".
-- * startBoostUp removed since it is now generated and used in Inverter_node_4K8K.vhd
-- **************************************************************************************	
-- 1.00: 090403 - SEROP/PRCB Björn Nyqvist
-- * A code review of this component has been completed.
-- **************************************************************************************
-- 1.01: 090406 - SEROP/PRCB Magnus Tysell	
-- * Pwm_synch_pulse(5 downto 0) changed to Pwm_synch_pulse(6 downto 1).
-- * DPRAM interface removed, using direct register access instead.
-- **************************************************************************************
	
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY Inverter_Node_TOP IS
  GENERIC (
    C_CLK_FREQ               : INTEGER RANGE 10_000_000 TO 130_000_000 := 100_000_000;
    C_PWM_UPDATE_RATE_US     : INTEGER RANGE 63 TO 126                 := 126;  -- PWM update rate in microseconds 
    C_PWM_MIN_PULSE_WIDTH_US : INTEGER RANGE 3 TO 6                    := 5;  -- PWM min pulse width time in microseconds
    NR_OF_NODES              : INTEGER RANGE 1 TO 6                    := 6
    );
  PORT
    (
      clk              : IN STD_LOGIC;
      rst_n            : IN STD_LOGIC;
      EtherCat_failure : IN STD_LOGIC;
      Pwm_synch_pulse  : IN STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
      u_switch_Node1   : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      v_switch_Node1   : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      w_switch_Node1   : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      u_switch_Node2   : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      v_switch_Node2   : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      w_switch_Node2   : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      u_switch_Node3   : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      v_switch_Node3   : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      w_switch_Node3   : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      u_switch_Node4   : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      v_switch_Node4   : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      w_switch_Node4   : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      u_switch_Node5   : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      v_switch_Node5   : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      w_switch_Node5   : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      u_switch_Node6   : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      v_switch_Node6   : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      w_switch_Node6   : IN STD_LOGIC_VECTOR(13 DOWNTO 0);

      U_pwm_top_1    : OUT STD_LOGIC;
      U_pwm_bottom_1 : OUT STD_LOGIC;
      V_pwm_top_1    : OUT STD_LOGIC;
      V_pwm_bottom_1 : OUT STD_LOGIC;
      W_pwm_top_1    : OUT STD_LOGIC;
      W_pwm_bottom_1 : OUT STD_LOGIC;

      U_pwm_top_2    : OUT STD_LOGIC;
      U_pwm_bottom_2 : OUT STD_LOGIC;
      V_pwm_top_2    : OUT STD_LOGIC;
      V_pwm_bottom_2 : OUT STD_LOGIC;
      W_pwm_top_2    : OUT STD_LOGIC;
      W_pwm_bottom_2 : OUT STD_LOGIC;

      U_pwm_top_3    : OUT STD_LOGIC;
      U_pwm_bottom_3 : OUT STD_LOGIC;
      V_pwm_top_3    : OUT STD_LOGIC;
      V_pwm_bottom_3 : OUT STD_LOGIC;
      W_pwm_top_3    : OUT STD_LOGIC;
      W_pwm_bottom_3 : OUT STD_LOGIC;

      U_pwm_top_4    : OUT STD_LOGIC;
      U_pwm_bottom_4 : OUT STD_LOGIC;
      V_pwm_top_4    : OUT STD_LOGIC;
      V_pwm_bottom_4 : OUT STD_LOGIC;
      W_pwm_top_4    : OUT STD_LOGIC;
      W_pwm_bottom_4 : OUT STD_LOGIC;

      U_pwm_top_5    : OUT STD_LOGIC;
      U_pwm_bottom_5 : OUT STD_LOGIC;
      V_pwm_top_5    : OUT STD_LOGIC;
      V_pwm_bottom_5 : OUT STD_LOGIC;
      W_pwm_top_5    : OUT STD_LOGIC;
      W_pwm_bottom_5 : OUT STD_LOGIC;

      U_pwm_top_6    : OUT STD_LOGIC;
      U_pwm_bottom_6 : OUT STD_LOGIC;
      V_pwm_top_6    : OUT STD_LOGIC;
      V_pwm_bottom_6 : OUT STD_LOGIC;
      W_pwm_top_6    : OUT STD_LOGIC;
      W_pwm_bottom_6 : OUT STD_LOGIC;

      deadTimeInverter1 : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      deadTimeInverter2 : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      deadTimeInverter3 : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      deadTimeInverter4 : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      deadTimeInverter5 : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      deadTimeInverter6 : IN STD_LOGIC_VECTOR(11 DOWNTO 0);

      inverterFailure         : OUT STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
      resetInverterFailure    : IN  STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
      resetInverterFailureAck : OUT STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
      inverterShortCircuit    : OUT STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
      inverterTempTooHigh     : OUT STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
      gateDriveTrip_n         : IN  STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
      gateDriveFltClr         : OUT STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
      pwmOn                   : IN  STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
      pwmSwFreq               : IN  STD_LOGIC_VECTOR(NR_OF_NODES DOWNTO 1);
      puTrigg                 : IN  STD_LOGIC;
      powerBoardSupplyFail    : IN  STD_LOGIC;
      mainsMissing            : IN  STD_LOGIC;
      fbkDataUpd              : IN  STD_LOGIC
      );

  ATTRIBUTE SIGIS        : STRING;
  ATTRIBUTE SIGIS OF Clk : SIGNAL IS "Clk";

END Inverter_Node_TOP;


ARCHITECTURE str OF Inverter_Node_TOP IS


  COMPONENT Inverter_Node
    GENERIC (
      C_CLK_FREQ               : INTEGER RANGE 10_000_000 TO 130_000_000 := 100_000_000;
      C_PWM_UPDATE_RATE_US     : INTEGER RANGE 63 TO 126                 := 126;  -- PWM update rate in microseconds
      C_PWM_MIN_PULSE_WIDTH_US : INTEGER RANGE 3 TO 6                    := 5  -- PWM min pulse width time in microseconds
      );
    PORT (
      clk                      : IN  STD_LOGIC;
      rst_n                    : IN  STD_LOGIC;
      EtherCat_failure         : IN  STD_LOGIC;
      Pwm_synch                : IN  STD_LOGIC;
      u_switch                 : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
      v_switch                 : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
      w_switch                 : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
      U_pwm_top                : OUT STD_LOGIC;
      U_pwm_bottom             : OUT STD_LOGIC;
      V_pwm_top                : OUT STD_LOGIC;
      V_pwm_bottom             : OUT STD_LOGIC;
      W_pwm_top                : OUT STD_LOGIC;
      W_pwm_bottom             : OUT STD_LOGIC;
      inverterFailure          : OUT STD_LOGIC;
      resetInverterFailure     : IN  STD_LOGIC;
      resetInverterFailureAck  : OUT STD_LOGIC;
      inverterShortCircuit     : OUT STD_LOGIC;
      inverterTempTooHigh      : OUT STD_LOGIC;
      gateDriveTrip_n          : IN  STD_LOGIC;
      gateDriveFltClr          : OUT STD_LOGIC;
      pwmOn                    : IN  STD_LOGIC;
      pwmSwFreq                : IN  STD_LOGIC;
      puTrigg                  : IN  STD_LOGIC;
      powerBoardSupplyFail     : IN  STD_LOGIC;
      mainsMissing             : IN  STD_LOGIC;
      fbkDataUpd               : IN  STD_LOGIC;
      deadTimeInverter         : IN  STD_LOGIC_VECTOR(11 DOWNTO 0)
      );
  END COMPONENT;

BEGIN
           
  Node_1 : Inverter_Node
    GENERIC MAP (
      C_CLK_FREQ               => C_CLK_FREQ,
      C_PWM_UPDATE_RATE_US     => C_PWM_UPDATE_RATE_US,
      C_PWM_MIN_PULSE_WIDTH_US => C_PWM_MIN_PULSE_WIDTH_US
      )
    PORT MAP (
      Clk                      => Clk,
      Rst_n                    => Rst_n,
      EtherCat_failure         => EtherCat_failure,
      Pwm_synch                => Pwm_synch_pulse(1),
      u_switch                 => u_switch_Node1,
      v_switch                 => v_switch_Node1,
      w_switch                 => w_switch_Node1,
      U_pwm_top                => U_pwm_top_1,
      U_pwm_bottom             => U_pwm_bottom_1,
      V_pwm_top                => V_pwm_top_1,
      V_pwm_bottom             => V_pwm_bottom_1,
      W_pwm_top                => W_pwm_top_1,
      W_pwm_bottom             => W_pwm_bottom_1,
      inverterFailure          => inverterFailure(1),
      resetInverterFailure     => resetInverterFailure(1),
      resetInverterFailureAck  => resetInverterFailureAck(1),
      inverterShortCircuit     => inverterShortCircuit(1),
      inverterTempTooHigh      => inverterTempTooHigh(1),
      gateDriveTrip_n          => gateDriveTrip_n(1),
      gateDriveFltClr          => gateDriveFltClr(1),
      pwmOn                    => pwmOn(1),
      pwmSwFreq                => pwmSwFreq(1),
      puTrigg                  => puTrigg,
      powerBoardSupplyFail     => powerBoardSupplyFail,
      mainsMissing             => mainsMissing,
      fbkDataUpd               => fbkDataUpd,
      deadTimeInverter         => deadTimeInverter1
      );

  Node_2 : Inverter_Node
    GENERIC MAP (
      C_CLK_FREQ               => C_CLK_FREQ,
      C_PWM_UPDATE_RATE_US     => C_PWM_UPDATE_RATE_US,
      C_PWM_MIN_PULSE_WIDTH_US => C_PWM_MIN_PULSE_WIDTH_US
      )
    PORT MAP (
      Clk                      => Clk,
      Rst_n                    => Rst_n,
      EtherCat_failure         => EtherCat_failure,
      Pwm_synch                => Pwm_synch_pulse(2),
      u_switch                 => u_switch_Node2,
      v_switch                 => v_switch_Node2,
      w_switch                 => w_switch_Node2,
      U_pwm_top                => U_pwm_top_2,
      U_pwm_bottom             => U_pwm_bottom_2,
      V_pwm_top                => V_pwm_top_2,
      V_pwm_bottom             => V_pwm_bottom_2,
      W_pwm_top                => W_pwm_top_2,
      W_pwm_bottom             => W_pwm_bottom_2,
      inverterFailure          => inverterFailure(2),
      resetInverterFailure     => resetInverterFailure(2),
      resetInverterFailureAck  => resetInverterFailureAck(2),
      inverterShortCircuit     => inverterShortCircuit(2),
      inverterTempTooHigh      => inverterTempTooHigh(2),
      gateDriveTrip_n          => gateDriveTrip_n(2),
      gateDriveFltClr          => gateDriveFltClr(2),
      pwmOn                    => pwmOn(2),
      pwmSwFreq                => pwmSwFreq(2),
      puTrigg                  => puTrigg,
      powerBoardSupplyFail     => powerBoardSupplyFail,
      mainsMissing             => mainsMissing,
      fbkDataUpd               => fbkDataUpd,
      deadTimeInverter         => deadTimeInverter2      
      ); 

  Node_3 : Inverter_Node
    GENERIC MAP (
      C_CLK_FREQ               => C_CLK_FREQ,
      C_PWM_UPDATE_RATE_US     => C_PWM_UPDATE_RATE_US,
      C_PWM_MIN_PULSE_WIDTH_US => C_PWM_MIN_PULSE_WIDTH_US
      )
    PORT MAP (
      Clk                      => Clk,
      Rst_n                    => Rst_n,
      EtherCat_failure         => EtherCat_failure,
      Pwm_synch                => Pwm_synch_pulse(3),
      u_switch                 => u_switch_Node3,
      v_switch                 => v_switch_Node3,
      w_switch                 => w_switch_Node3,      
      U_pwm_top                => U_pwm_top_3,
      U_pwm_bottom             => U_pwm_bottom_3,
      V_pwm_top                => V_pwm_top_3,
      V_pwm_bottom             => V_pwm_bottom_3,
      W_pwm_top                => W_pwm_top_3,
      W_pwm_bottom             => W_pwm_bottom_3,
      inverterFailure          => inverterFailure(3),
      resetInverterFailure     => resetInverterFailure(3),
      resetInverterFailureAck  => resetInverterFailureAck(3),
      inverterShortCircuit     => inverterShortCircuit(3),
      inverterTempTooHigh      => inverterTempTooHigh(3),
      gateDriveTrip_n          => gateDriveTrip_n(3),
      gateDriveFltClr          => gateDriveFltClr(3),
      pwmOn                    => pwmOn(3),
      pwmSwFreq                => pwmSwFreq(3),
      puTrigg                  => puTrigg,
      powerBoardSupplyFail     => powerBoardSupplyFail,
      mainsMissing             => mainsMissing,
      fbkDataUpd               => fbkDataUpd,
      deadTimeInverter         => deadTimeInverter3      
      );

  Node_4 : Inverter_Node
    GENERIC MAP (
      C_CLK_FREQ               => C_CLK_FREQ,
      C_PWM_UPDATE_RATE_US     => C_PWM_UPDATE_RATE_US,
      C_PWM_MIN_PULSE_WIDTH_US => C_PWM_MIN_PULSE_WIDTH_US
      )
    PORT MAP (
      Clk                      => Clk,
      Rst_n                    => Rst_n,
      EtherCat_failure         => EtherCat_failure,
      Pwm_synch                => Pwm_synch_pulse(4),
      u_switch                 => u_switch_Node4,
      v_switch                 => v_switch_Node4,
      w_switch                 => w_switch_Node4,        
      U_pwm_top                => U_pwm_top_4,
      U_pwm_bottom             => U_pwm_bottom_4,
      V_pwm_top                => V_pwm_top_4,
      V_pwm_bottom             => V_pwm_bottom_4,
      W_pwm_top                => W_pwm_top_4,
      W_pwm_bottom             => W_pwm_bottom_4,
      inverterFailure          => inverterFailure(4),
      resetInverterFailure     => resetInverterFailure(4),
      resetInverterFailureAck  => resetInverterFailureAck(4),
      inverterShortCircuit     => inverterShortCircuit(4),
      inverterTempTooHigh      => inverterTempTooHigh(4),
      gateDriveTrip_n          => gateDriveTrip_n(4),
      gateDriveFltClr          => gateDriveFltClr(4),
      pwmOn                    => pwmOn(4),
      pwmSwFreq                => pwmSwFreq(4),
      puTrigg                  => puTrigg,
      powerBoardSupplyFail     => powerBoardSupplyFail,
      mainsMissing             => mainsMissing,
      fbkDataUpd               => fbkDataUpd,
      deadTimeInverter         => deadTimeInverter4      
      );

  Node_5 : Inverter_Node
    GENERIC MAP (
      C_CLK_FREQ               => C_CLK_FREQ,
      C_PWM_UPDATE_RATE_US     => C_PWM_UPDATE_RATE_US,
      C_PWM_MIN_PULSE_WIDTH_US => C_PWM_MIN_PULSE_WIDTH_US
      )
    PORT MAP (
      Clk                      => Clk,
      Rst_n                    => Rst_n,
      EtherCat_failure         => EtherCat_failure,
      Pwm_synch                => Pwm_synch_pulse(5),
      u_switch                 => u_switch_Node5,
      v_switch                 => v_switch_Node5,
      w_switch                 => w_switch_Node5,        
      U_pwm_top                => U_pwm_top_5,
      U_pwm_bottom             => U_pwm_bottom_5,
      V_pwm_top                => V_pwm_top_5,
      V_pwm_bottom             => V_pwm_bottom_5,
      W_pwm_top                => W_pwm_top_5,
      W_pwm_bottom             => W_pwm_bottom_5,
      inverterFailure          => inverterFailure(5),
      resetInverterFailure     => resetInverterFailure(5),
      resetInverterFailureAck  => resetInverterFailureAck(5),
      inverterShortCircuit     => inverterShortCircuit(5),
      inverterTempTooHigh      => inverterTempTooHigh(5),
      gateDriveTrip_n          => gateDriveTrip_n(5),
      gateDriveFltClr          => gateDriveFltClr(5),
      pwmOn                    => pwmOn(5),
      pwmSwFreq                => pwmSwFreq(5),
      puTrigg                  => puTrigg,
      powerBoardSupplyFail     => powerBoardSupplyFail,
      mainsMissing             => mainsMissing,
      fbkDataUpd               => fbkDataUpd,
      deadTimeInverter         => deadTimeInverter5      
      );

  Node_6 : Inverter_Node
    GENERIC MAP (
      C_CLK_FREQ               => C_CLK_FREQ,
      C_PWM_UPDATE_RATE_US     => C_PWM_UPDATE_RATE_US,
      C_PWM_MIN_PULSE_WIDTH_US => C_PWM_MIN_PULSE_WIDTH_US
      )
    PORT MAP (
      Clk                      => Clk,
      Rst_n                    => Rst_n,
      EtherCat_failure         => EtherCat_failure,
      Pwm_synch                => Pwm_synch_pulse(6),
      u_switch                 => u_switch_Node6,
      v_switch                 => v_switch_Node6,
      w_switch                 => w_switch_Node6,        
      U_pwm_top                => U_pwm_top_6,
      U_pwm_bottom             => U_pwm_bottom_6,
      V_pwm_top                => V_pwm_top_6,
      V_pwm_bottom             => V_pwm_bottom_6,
      W_pwm_top                => W_pwm_top_6,
      W_pwm_bottom             => W_pwm_bottom_6,
      inverterFailure          => inverterFailure(6),
      resetInverterFailure     => resetInverterFailure(6),
      resetInverterFailureAck  => resetInverterFailureAck(6),
      inverterShortCircuit     => inverterShortCircuit(6),
      inverterTempTooHigh      => inverterTempTooHigh(6),
      gateDriveTrip_n          => gateDriveTrip_n(6),
      gateDriveFltClr          => gateDriveFltClr(6),
      pwmOn                    => pwmOn(6),
      pwmSwFreq                => pwmSwFreq(6),
      puTrigg                  => puTrigg,
      powerBoardSupplyFail     => powerBoardSupplyFail,
      mainsMissing             => mainsMissing,
      fbkDataUpd               => fbkDataUpd,
      deadTimeInverter         => deadTimeInverter6      
      );

END ARCHITECTURE str;
