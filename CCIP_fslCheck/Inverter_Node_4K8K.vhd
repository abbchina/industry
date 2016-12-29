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
-- Title:               Inverter node
-- File name:           Inverter_node_4k8k.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:		1.00
-- Prepared by:		SEROP/PRCB 
-- Status:		Reviewed
-- Date:		2009-04-03
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
-- 0.05: 090226 - SEROP/PRCB Björn Nyqvist
-- * PWM_cfg removed since it is redundant, pwmSwFreq is used instead
-- * waitForReset state added for overTemp
-- **************************************************************************************	
-- 0.06: 090307 - SEROP/PRCB Björn Nyqvist
-- * Bug fix: nr_of_reads in DPM copy process didn't had a reset value
-- **************************************************************************************
-- 0.07: 090331 - SEROP/PRCB Björn Nyqvist
-- * pwmOn_d removed from entity, it is now generated in this block.
-- * Pwm_synch_n changed name to Pwm_synch since it is not active low.
-- * startBoostUp removed from entity since the start of boost procedure is now
--   handled in this block (pwmOn_i and boostInProgress)
-- * Comments inserted and cosmetic updates.
-- * DPRAM interface removed, using direct register mapping instead.
-- **************************************************************************************	
-- 1.00: 090401 - SEROP/PRCB Björn Nyqvist
-- * A code review of this component has been completed.
-- **************************************************************************************	
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;
USE ieee.numeric_std.ALL;

ENTITY Inverter_Node IS
  GENERIC(
    C_CLK_FREQ               : INTEGER RANGE 10_000_000 TO 130_000_000 := 100_000_000;
    C_PWM_UPDATE_RATE_US     : INTEGER RANGE 63 TO 126 := 126;  -- PWM update rate in microseconds
    C_PWM_MIN_PULSE_WIDTH_US : INTEGER RANGE 3 TO 6    := 5  -- PWM min pulse width time in microseconds
    );
  PORT(
    clk                     : IN  STD_LOGIC;
    rst_n                   : IN  STD_LOGIC;
    EtherCat_failure        : IN  STD_LOGIC;
    Pwm_synch               : IN  STD_LOGIC;
    u_switch                : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
    v_switch                : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
    w_switch                : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
    U_pwm_top               : OUT STD_LOGIC;
    U_pwm_bottom            : OUT STD_LOGIC;
    V_pwm_top               : OUT STD_LOGIC;
    V_pwm_bottom            : OUT STD_LOGIC;
    W_pwm_top               : OUT STD_LOGIC;
    W_pwm_bottom            : OUT STD_LOGIC;
    inverterFailure         : OUT STD_LOGIC;
    resetInverterFailure    : IN  STD_LOGIC;
    resetInverterFailureAck : OUT STD_LOGIC;
    inverterShortCircuit    : OUT STD_LOGIC;
    inverterTempTooHigh     : OUT STD_LOGIC;
    gateDriveTrip_n         : IN  STD_LOGIC;
    gateDriveFltClr         : OUT STD_LOGIC;
    pwmOn                   : IN  STD_LOGIC;
    pwmSwFreq               : IN  STD_LOGIC;
    puTrigg                 : IN  STD_LOGIC;
    powerBoardSupplyFail    : IN  STD_LOGIC;
    mainsMissing            : IN  STD_LOGIC;
    fbkDataUpd              : IN  STD_LOGIC;
    deadTimeInverter        : IN  STD_LOGIC_VECTOR(11 DOWNTO 0)
    );
  
  ATTRIBUTE SIGIS        : STRING;
  ATTRIBUTE SIGIS OF clk : SIGNAL IS "clk";
  
END Inverter_Node;

ARCHITECTURE rtl OF Inverter_Node IS

  -- 4x63us ticks + the time until the 1st tick is detected: 4+1=5. Used to
  -- decide when in time to issue a gate driver clear pulse.
  CONSTANT NO_OF_63US_TICKS : INTEGER := 5;  

  -- 3 consecutive PWM switch-on-commands per axis = 3x63us ticks, since every
  -- second tick addressing mains axis respectively the wrist axis, 3
  -- consecutive = 2x3x63us, i.e. 6x63us
  CONSTANT THREE_CONSECUTIVE_PWMON : INTEGER := 6;

  -- Clr pulse is 40 us (since filter delay of gateDriveTrip_n is 32us). 4 ticks = 40
  -- us + 1 to compensate if started in between two clk100KHzEn pulses.
  CONSTANT TIMEOUT_40us         : INTEGER := 5;

  TYPE supervision_t IS (waitForTrip, waitForSupplyOk, waitUntilTripIsNormal, waitForIrq, doClrPulse,
                         handleShortCircuit, handleOverTemp, waitForReset, waitForFbkDataUpd);
  SIGNAL supState               : supervision_t;
  SIGNAL noOfShortCircuit       : NATURAL RANGE 0 TO 3;
  SIGNAL irqCnt                 : NATURAL RANGE 0 TO THREE_CONSECUTIVE_PWMON;
  SIGNAL inverterFailure_i      : STD_LOGIC;
  SIGNAL inverterShortCircuit_i : STD_LOGIC;
  SIGNAL inverterTempTooHigh_i  : STD_LOGIC;
  SIGNAL fltClrPulse            : STD_LOGIC;
  SIGNAL clrPulseTimer          : NATURAL RANGE 0 TO TIMEOUT_40us;
  SIGNAL shortCircuitTimer      : NATURAL RANGE 0 TO NO_OF_63US_TICKS*3;
  SIGNAL shortCircuitDetected   : STD_LOGIC;
  SIGNAL gateDriveFltClr_i      : STD_LOGIC;
  SIGNAL rstInverterFailure_d   : STD_LOGIC;
  SIGNAL gateDriveTrip_n_i1     : STD_LOGIC;
  SIGNAL gateDriveTrip_n_i2     : STD_LOGIC;  

  CONSTANT DPRAM_WIDTH          : NATURAL := 6;
  CONSTANT PWM_CTRL_ADDR        : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"111_111";
  CONSTANT PWM_CFG_ADDR         : STD_LOGIC_VECTOR(DPRAM_WIDTH-1 DOWNTO 0) := B"111_110";
  CONSTANT NUMBER_OF_READ_WORDS : NATURAL := 5;
  SIGNAL   nr_of_reads          : NATURAL RANGE 0 TO NUMBER_OF_READ_WORDS + 3;

  TYPE STATE_TYPE IS (Idle, DPRAM_Read);
  SIGNAL state    : STATE_TYPE;

  SIGNAL U_pwm_bottom_i : STD_LOGIC;
  SIGNAL V_pwm_bottom_i : STD_LOGIC;
  SIGNAL W_pwm_bottom_i : STD_LOGIC;
  
  TYPE BOOSTUP_TYPE IS (Idle, Charge);
  SIGNAL boostUpState      : BOOSTUP_TYPE;
--  SIGNAL timer_10us      : STD_LOGIC_VECTOR(9 DOWNTO 0);
--  SIGNAL timer_10us_tick : STD_LOGIC;
  SIGNAL timer_655us      : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL timer_655us_tick : STD_LOGIC;
  SIGNAL counter           : STD_LOGIC_VECTOR(4 DOWNTO 0);
  SIGNAL boostInProgress   : STD_LOGIC;
  SIGNAL boostInProgress_d : STD_LOGIC;
  SIGNAL pwmSwitch         : STD_LOGIC;
  SIGNAL pwmOn_d           : STD_LOGIC;
  SIGNAL pwmOn_i           : STD_LOGIC;  
  SIGNAL pwmOff            : STD_LOGIC;

  CONSTANT GATEDRIVE_FLT_CLR_TIME : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"800";  --20us  
  SIGNAL faultClrCounter      : STD_LOGIC_VECTOR(11 DOWNTO 0);
  TYPE TIMER_TYPE IS (Timer_Idle, Timer_Run);
  SIGNAL timer_state          : TIMER_TYPE;

  SIGNAL clk100KHzEn             : STD_LOGIC;
  SIGNAL clkCnt                  : NATURAL RANGE 0 TO 999;
  ATTRIBUTE SIGIS of clk100KHzEn : SIGNAL IS "CLK";

-------------------------------------------------------------------------------
-- Component declarations:
-------------------------------------------------------------------------------  

  COMPONENT pwm
    GENERIC (
      C_CLK_FREQ               : INTEGER RANGE 10_000_000 TO 130_000_000 := 100_000_000;
      C_PWM_UPDATE_RATE_US     : INTEGER RANGE 63 TO 126 := 126;  -- PWM update rate in microseconds
      C_PWM_MIN_PULSE_WIDTH_US : INTEGER RANGE 3 TO 6    := 5  -- PWM min pulse width time in microseconds
      );
    PORT (
      clk              : IN  STD_LOGIC;
      Resetn           : IN  STD_LOGIC;      
      Pwm_synch        : IN  STD_LOGIC;
      PWM_ASYM_or_SYM  : IN  STD_LOGIC;
      Stop             : IN  STD_LOGIC;
      U_switch         : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
      V_switch         : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
      W_switch         : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
      U_pwm_top        : OUT STD_LOGIC;
      U_pwm_bottom     : OUT STD_LOGIC;
      V_pwm_top        : OUT STD_LOGIC;
      V_pwm_bottom     : OUT STD_LOGIC;
      W_pwm_top        : OUT STD_LOGIC;
      W_pwm_bottom     : OUT STD_LOGIC;
      deadTimeInverter : IN  STD_LOGIC_VECTOR(11 DOWNTO 0)
      );
  END COMPONENT;

  COMPONENT medianFilter IS
    GENERIC (
      nrOfFlipFlops  : INTEGER;
      setRstPolarity : STRING
      );
    PORT(
      rst_n     : IN  STD_LOGIC;
      clk       : IN  STD_LOGIC;
      din       : IN  STD_LOGIC;
      dout      : OUT STD_LOGIC
    );
  END COMPONENT;

  COMPONENT lowPassFilter
    GENERIC (
      decimationFactor : INTEGER;
      setRstPolarity   : STRING;
      filterLength     : INTEGER
      );
    PORT(
      rst_n          : IN  STD_LOGIC;
      clk            : IN  STD_LOGIC;
      din            : IN  STD_LOGIC;
      dout           : OUT STD_LOGIC
      );
  END COMPONENT lowPassFilter;


BEGIN

-------------------------------------------------------------------------------
-- Component instantiations:
-------------------------------------------------------------------------------  
     medianFilter_i0 : medianFilter
     GENERIC MAP(
       nrOfFlipFlops  => 5,
       setRstPolarity => "high"
       )
     PORT MAP(
       rst_n          => rst_n,
       clk            => clk,
       din            => gateDriveTrip_n,
       dout           => gateDriveTrip_n_i1
      );

   lowPassFilter_i0 : lowPassFilter
     GENERIC MAP(
       decimationFactor => 100,
       setRstPolarity   => "high",
       filterLength     => 32
       )
     PORT MAP(
       rst_n          => rst_n,
       clk            => clk,
       din            => gateDriveTrip_n_i1,
       dout           => gateDriveTrip_n_i2
       );

-------------------------------------------------------------------------------

  -- Generating a start/stop control signal for PWM generation:
  pwmOff <= NOT pwmOn_i WHEN (EtherCat_failure = '0') ELSE '1';

  -- PWM outputs are set to '1' when boost in progress, i.e. pwmSwitch=1:
  U_pwm_bottom <= '1' WHEN pwmSwitch = '1' ELSE U_pwm_bottom_i;
  V_pwm_bottom <= '1' WHEN pwmSwitch = '1' ELSE V_pwm_bottom_i;
  W_pwm_bottom <= '1' WHEN pwmSwitch = '1' ELSE W_pwm_bottom_i;

  -- Generating the fault clear signal to the gate driver, where:
  -- * fltClrPulse       = automatically set to clear a short circuit
  -- * boostInProgress   = set during the boost up sequence
  -- * gateDriveFltClr_i = set upon clear request written by AXC
  gateDriveFltClr <= '1' WHEN fltClrPulse = '1' ELSE 
                     '1' WHEN boostInProgress = '1' ELSE gateDriveFltClr_i;
-------------------------------------------------------------------------------
-- 100 KHz clock enable generation
-------------------------------------------------------------------------------
   gen100KHz : PROCESS (clk, rst_n)
   BEGIN 
     IF rst_n = '0' THEN
       clkCnt <= 0;
       clk100KHzEn   <= '0';
     ELSIF clk'event AND clk = '1' THEN
       IF clkCnt = 999 THEN
         clkCnt <= 0;
         clk100KHzEn <= '1';
       ELSE
         clkCnt <= clkCnt + 1;
         clk100KHzEn <= '0';
       END IF;
     END IF;
   END PROCESS gen100KHz;

-------------------------------------------------------------------------------
-- Gate driver supervision state machine
-------------------------------------------------------------------------------
  -- Purpose: Supervise the gate driver and take care of its faults.
  -- A number of faults is reported by the gate driver: undervoltage, short
  -- circuit and overtemperature. All those are handled by this state machine.
  -- Undervoltage is not reported whereas the are two types will be reported
  -- with separated status bits as a "warning" and upon three consecutive
  -- faults, the common status bit inverterFailure will be set indicating a
  -- permanent "error" which must be cleared by the AXC. Power off, i.e.
  -- mainsMissing = '1' will also clear an inverterFailure.
  -- puTrigg is used to determine when in time a clear pulse shall take place.
  -- puTrigg is asserted each 63 us tick.

  gateDriverSupervison: PROCESS (clk, rst_n)
  BEGIN
    IF rst_n = '0' THEN
      supState <= waitForTrip;
      clrPulseTimer <= 0;
      fltClrPulse   <= '0';               
      noOfShortCircuit <= 0;
      shortCircuitTimer <= 0;      
      irqCnt <= 0;      
      inverterFailure_i <= '0';     
      inverterShortCircuit_i <= '0';
      inverterTempTooHigh_i  <= '0'; 
      shortCircuitDetected <= '0';
    ELSIF clk'event AND clk = '1' THEN

      IF mainsMissing = '1' OR resetInverterFailure = '1' THEN
        shortCircuitTimer <= 0;
        noOfShortCircuit <= 0;
      ELSIF shortCircuitDetected = '1' THEN
        IF puTrigg = '1' THEN
          IF shortCircuitTimer = (NO_OF_63US_TICKS)*3 THEN
            -- If three consecutive short circuits is detected within a certain
            -- time from that the first short circuit is detected, i.e.
            -- "shortCircuitDetected = '1'", inverterFailure shall be set. By
            -- ending up here, three short circuits were not detected in time.
            noOfShortCircuit <= 0;
            shortCircuitDetected <= '0';
            shortCircuitTimer <= 0;            
          ELSE
            shortCircuitTimer <= shortCircuitTimer + 1;  
          END IF;
        END IF;
      END IF;

      CASE supState IS
        
        WHEN waitForTrip =>
          irqCnt <= 0;
          IF gateDriveTrip_n_i2 = '0' AND mainsMissing = '0' THEN
            -- gate driver fault detected
            IF powerBoardSupplyFail = '1' THEN
              supState <= waitForSupplyOk;
            ELSE
              supState <= waitForIrq;
            END IF;
          ELSE
            supState <= waitForTrip;
          END IF;

          
        WHEN waitForSupplyOk =>
          -- Do not report undervoltage
          IF mainsMissing = '1' THEN
            supState <= waitForTrip;
          ElSIF powerBoardSupplyFail = '0' OR resetInverterFailure = '1' THEN
            supState <= waitUntilTripIsNormal;
          ELSE
            supState <= waitForSupplyOk; 
          END IF;

          
        WHEN waitUntilTripIsNormal =>
          -- To avoid false trigs. E.g. upon a power supply failure: the
          -- powerBoardSupplyFailure will likely go low before gateDriveTrip_n
          -- turns high, possible race condition.
          IF mainsMissing = '1' OR gateDriveTrip_n_i2 = '1' THEN
            supState <= waitForTrip;
          ELSE
            supState <= waitUntilTripIsNormal; 
          END IF;
          

        WHEN waitForIrq =>
          -- Wait a certain number of interrupts until the clear pulse shall be
          -- issued.
          IF irqCnt = NO_OF_63US_TICKS THEN
            supState <= doClrPulse;
            irqCnt <= 0;
          ELSIF gateDriveTrip_n_i2 = '1' THEN
            -- The fault was released, i.e. an undervoltage or overtemp
            supState <= waitForTrip;
          ELSE
            IF puTrigg = '1' THEN
              irqCnt <= irqCnt + 1;
            ELSE
              irqCnt <= irqCnt;
            END IF;
          END IF;

          
        WHEN doClrPulse =>
          IF clrPulseTimer = TIMEOUT_40us THEN
            fltClrPulse <= '0';
          ELSE
            fltClrPulse <= '1';
            IF clk100KHzEn = '1' THEN
              clrPulseTimer <= clrPulseTimer + 1;
            ELSE
              clrPulseTimer <= clrPulseTimer;
            END IF;
          END IF;

          IF gateDriveTrip_n_i2 = '1' THEN
            -- It was a shortCircuit since a clear pulse unlatched the fault
            supState <= handleShortCircuit;
            clrPulseTimer <= 0;
            shortCircuitDetected <= '1';
            IF noOfShortCircuit = 3 THEN
              noOfShortCircuit <= noOfShortCircuit;
            ELSE
              noOfShortCircuit <= noOfShortCircuit + 1;
            END IF;
          ELSIF clrPulseTimer = TIMEOUT_40us AND gateDriveTrip_n_i2 = '0' THEN
            -- It was a overTemp since a clear pulse did not unlatch the fault
            supState <= handleOverTemp;
            clrPulseTimer <= 0;
          END IF;

          
        WHEN handleShortCircuit =>
          inverterShortCircuit_i <= '1';
          fltClrPulse <= '0';
          IF mainsMissing = '1' THEN
            supState <= waitForTrip;
            inverterFailure_i <= '0';
            inverterShortCircuit_i <= '0';
          ELSIF noOfShortCircuit = 3 THEN
            supState <= waitForFbkDataUpd;
            inverterFailure_i <= '1';
          ELSIF noOfShortCircuit < 3 THEN
            supState <= waitForFbkDataUpd;            
          END IF;

          
        WHEN handleOverTemp => 
          IF mainsMissing = '1' OR resetInverterFailure = '1' THEN
            inverterTempTooHigh_i <= '0';
            inverterFailure_i <= '0';
            supState <= waitForTrip;
          ELSIF gateDriveTrip_n_i2 = '1' THEN
            -- Temp normal again
            inverterTempTooHigh_i <= '0';            
            IF inverterFailure_i = '1' THEN
              -- The inverterFailure bit must be cleared
              supState <= waitForReset;
            ELSE
              supState <= waitForTrip;
            END IF;
          ELSE
            -- The "gateDriveTrip_n_i2" equals to '0'
            inverterTempTooHigh_i <= '1';
            supState <= handleOverTemp;            
            IF irqCnt < THREE_CONSECUTIVE_PWMON THEN              
              inverterFailure_i <= '0';
            ELSE
              inverterFailure_i <= '1';
            END IF;
          END IF;

          IF irqCnt = THREE_CONSECUTIVE_PWMON THEN
            irqCnt <= irqCnt;
          ELSE
            IF puTrigg = '1' THEN
              irqCnt <= irqCnt + 1;
            ELSE
              irqCnt <= irqCnt;
            END IF;
          END IF;
          

        WHEN waitForReset =>
          -- Clear the inverterFail bit upon overTemp
          IF resetInverterFailure = '1' THEN
            supState <= waitForTrip;
            inverterFailure_i <= '0';
          ELSE
            supState <= waitForReset;
          END IF;

          
        WHEN waitForFbkDataUpd =>
          IF inverterFailure_i = '1' THEN
            IF resetInverterFailure = '1' OR mainsMissing = '1' THEN
              -- Jump to "waitUntilTripIsNormal" to not detect a false fault
              -- before the reset cmd has been completed.
              supState <= waitUntilTripIsNormal;
              inverterFailure_i <= '0';
              inverterShortCircuit_i <= '0';
            ELSE
              -- Still waiting for reset cmd or mainsMissing
              supState <= waitForFbkDataUpd;
              inverterFailure_i <= inverterFailure_i;
              inverterShortCircuit_i <= inverterShortCircuit_i;              
            END IF;
          ELSIF fbkDataUpd = '1' THEN
            -- The inverterShortCircuit warning has now been sent to AXC.
            supState <= waitForTrip;
            inverterFailure_i <= '0';
            inverterShortCircuit_i <= '0';
          ELSE
            -- Still waiting that the feedback data shall be read.
            supState <= waitForFbkDataUpd;
          END IF;

          
        WHEN OTHERS =>
          supState <= waitForTrip;
                       
      END CASE;
    END IF;
  END PROCESS gateDriverSupervison;
---------------------------------------------------------------------------------
---- Generate a pulse each 10 us
---------------------------------------------------------------------------------
--  timer_10_us :
--  PROCESS (clk, rst_n)
--  BEGIN
--    IF (rst_n = '0') THEN
--      timer_10us      <= (OTHERS => '0');
--      timer_10us_tick <= '0';
--    ELSIF (clk'event AND clk = '1') THEN
--      timer_10us        <= timer_10us + 1;
--      IF (timer_10us = X"3FF") THEN
--        timer_10us_tick <= '1';
--      ELSE
--        timer_10us_tick <= '0';
--      END IF;
--    END IF;
--  END PROCESS;
     
-------------------------------------------------------------------------------
-- Generate a pulse each 655 us
-------------------------------------------------------------------------------
  timer_655_us :
  PROCESS (clk, rst_n)
  BEGIN
    IF (rst_n = '0') THEN
      timer_655us      <= (OTHERS => '0');
      timer_655us_tick <= '0';
    ELSIF (clk'event AND clk = '1') THEN
      timer_655us        <= timer_655us + 1;
      IF (timer_655us = X"FFFF") THEN
        timer_655us_tick <= '1';
      ELSE
        timer_655us_tick <= '0';
      END IF;
    END IF;
  END PROCESS;
  
-------------------------------------------------------------------------------
-- Boost up sequence of the gate driver, see IR2114 data sheet for further info
-------------------------------------------------------------------------------

  -- Purpose: The boost up is used for supplying the high side stage of the gate
  -- driver at power supply start-up. As power-up is not directly connected to
  -- pwm on in the drive system, we do the boost at "pwm on" instead. Otherwise, 
  -- the capacitor voltage might drop too much. Compare power-up to we actually
  -- go "pwm on", i.e. start the robot program.
  -- The boost up sequence is triggered by the first pwmOn command and implies
  -- that the gate drivers' lower leg is turned on for a certain time
  -- irrespective of the first PWM switch time.

  Boost_up_axis :
 PROCESS (clk, rst_n)
  BEGIN
    IF (rst_n = '0') THEN
      boostUpState <= Idle;
      counter <= (OTHERS => '0');
      pwmSwitch <= '0';
      boostInProgress <= '0';
      boostInProgress_d <= '0';      
      pwmOn_d <= '0';
      pwmOn_i <= '0';      
    ELSIF (clk'event AND clk = '1') THEN
      pwmOn_d <= pwmOn;
      boostInProgress_d <= boostInProgress;

      IF boostInProgress = '0' AND boostInProgress_d = '1' THEN
        -- Activate PWM when boost procedure has completed
        pwmOn_i <= '1';
      ELSIF pwmOn = '0' THEN
        -- PWM turned off by AXC
        pwmOn_i <= '0';
      ELSE
        pwmOn_i <= pwmOn_i;
      END IF;
        
      CASE boostUpState IS
        
        WHEN Idle  =>
          IF (pwmOn = '1' AND pwmOn_d = '0') THEN
            boostUpState <= Charge;
          END IF;
          counter <= (OTHERS => '0');
          pwmSwitch <= '0';
          boostInProgress <= '0';
          
        WHEN Charge =>
          boostInProgress <= '1';
          IF (timer_655us_tick = '1') THEN
            counter <= counter + 1;
          END IF;
          IF (counter = "00011") THEN
            -- Start charging the bootstrap capacitor
            pwmSwitch <= '1';
          ELSIF (counter = "10010") THEN
            -- Stop charging the bootstrap capacitor            
            pwmSwitch <= '0';
          ELSIF (counter = "10100") THEN
            boostUpState <= Idle;
          END IF;
          
      END CASE;
    END IF;
  END PROCESS;

-------------------------------------------------------------------------------
-- Handling gate driver clear command which is issued by the AXC.
-------------------------------------------------------------------------------  
  FLT_CLR_TIMER_20us :
   PROCESS(clk, rst_n)
   BEGIN
     IF (rst_n = '0') THEN
       gateDriveFltClr_i <= '0';
       faultClrCounter <= (OTHERS => '0');
       timer_state <= Timer_Idle;
       rstInverterFailure_d <= '0';
     ELSIF (clk'event AND clk = '1') THEN
       rstInverterFailure_d <= resetInverterFailure;
       
       CASE timer_state IS
         
         WHEN Timer_Idle =>
           gateDriveFltClr_i <= '0';
           faultClrCounter <= (OTHERS => '0');
           IF (resetInverterFailure = '1' AND rstInverterFailure_d = '0') THEN
             timer_state <= Timer_Run;
           END IF;

         WHEN Timer_Run =>
           gateDriveFltClr_i <= '1';           
           faultClrCounter <= faultClrCounter + 1;
           IF faultClrCounter = GATEDRIVE_FLT_CLR_TIME then
             -- 20,48 ms clear pulse is now generated
             timer_state <= Timer_Idle;
           END IF;
           
       END CASE;
     END IF;
   END PROCESS;


   PWM_IP : pwm
     GENERIC MAP(
       C_CLK_FREQ               => C_CLK_FREQ,
       C_PWM_UPDATE_RATE_US     => C_PWM_UPDATE_RATE_US,
       C_PWM_MIN_PULSE_WIDTH_US => C_PWM_MIN_PULSE_WIDTH_US
       )
     PORT MAP (
       clk                      => clk,
       Resetn                   => rst_n,
       Pwm_synch                => Pwm_synch,
       PWM_ASYM_or_SYM          => pwmSwFreq,
       Stop                     => pwmOff,
       U_switch                 => u_switch,
       V_switch                 => v_switch,
       W_switch                 => w_switch,
       U_pwm_top                => U_pwm_top,
       U_pwm_bottom             => U_pwm_bottom_i,
       V_pwm_top                => V_pwm_top,
       V_pwm_bottom             => V_pwm_bottom_i,
       W_pwm_top                => W_pwm_top,
       W_pwm_bottom             => W_pwm_bottom_i,
       deadTimeInverter         => deadTimeInverter
       );
  
-------------------------------------------------------------------------------
-- Continuous assignments 
-------------------------------------------------------------------------------
  resetInverterFailureAck <= rstInverterFailure_d;
  inverterFailure         <= inverterFailure_i;
  inverterShortCircuit    <= inverterShortCircuit_i;
  inverterTempTooHigh     <= inverterTempTooHigh_i;
  
END ARCHITECTURE rtl;  
