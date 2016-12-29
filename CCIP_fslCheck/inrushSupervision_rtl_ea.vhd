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
-- Title:               Rectifier Controller DC unit
-- File name:           rectCtrlDC_rtl_ea.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:		1.9
-- Prepared by:		SEROP/PRCB Björn Nyqvist
-- Status:		Edited
-- Date:		2009-02-09
-- **************************************************************************************
-- References:
-- 1. Design Specification Rectifier Controller 3HAC030434-001
-- 2. TRS MINK Power and Capacitor Unit 3HAC027503-001
-- 3. EK Gränssnittsbeskrivning rev D
-- **************************************************************************************
-- Functional description:

-- Manage DC link related functions in the rectifer controller, broadly to
-- supervise the inrush circuit and to control the brake chopper to bleed off
-- excessive volt on the DC link.
--
-- See respectively process for further information.
--
-- Abbreviations:
--  LV = Low Voltage
--  HV = High Voltage
--  1P = 1 Phase supply
--  3P = 3 Phase supply
-- **************************************************************************************
-- changes:
-- 1.1 080203 BjNy: Bleeder is engaged when DC too high i.e. DC outside permitted voltage window.
-- 1.2 080402 BjNy: wait50ms even though DC > AC at startup.
-- 1.3 080411 BjNy: Scale factor of 4.8 on AC_V and DC_V inserted.
-- 1.4 080528 BjNy: Updated to conform to MDU P1.1.
-- 1.5 081207 BjNy: Completely updated for the new inrush curcuit on MDU P2.
-- 1.6 090118 BjNy: clk100KhzEn_d removed. mainsVACType check added to bleederOn.
-- 1.7 090121 BjNy: Separate bleederOn_i from engageBleederForTest.
-- 1.8 090125 BjNy: Added check of dcStable after bleederTest has been completed.
-- 1.9 090209 BjNy: The three new"XX"SampleEnable signals are removed to
-- reflect the changes in PU_TOP where the adcDataEnable now handles this
-- function. The adcDataEnable is set every 63us as before whereas the ADC data is now
-- updated every 126us. The relay voltage window changed to 9-14VDC due to the
-- power board supply changed from 18VDC to 17VDC.
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY inrushSupervision IS
  PORT(
    debugMode            : IN  STD_LOGIC;
    rst_n                : IN  STD_LOGIC;
    clk                  : IN  STD_LOGIC;
    clk100KHzEn          : IN  STD_LOGIC;
    cfgDone              : IN  STD_LOGIC;
    mainsVACType         : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
    bleederTurnOnLevel   : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    bleederTurnOffLevel  : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    bleederTestLevel     : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    dcSettleLevel        : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    dcEngageLevel        : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    dcDisengageLevel     : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    dcVoltage            : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    bleederVoltage       : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    re1Voltage           : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    re2Voltage           : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    adcDataUpdated       : IN  STD_LOGIC;
    mainsMissing         : IN  STD_LOGIC;
    bleederShortCircuit  : IN  STD_LOGIC;
    relayFailure         : OUT STD_LOGIC;
    bleederOpen          : OUT STD_LOGIC;
    inrushResistorOpen   : OUT STD_LOGIC;
    inrushActive         : OUT STD_LOGIC;
    reOn                 : OUT STD_LOGIC;
    bleederOn            : OUT STD_LOGIC
    );
END inrushSupervision;

ARCHITECTURE rtl OF inrushSupervision IS

--  CONSTANT RE_LOW_LEVEL         : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"50F";  --(8V)
--  CONSTANT RE_HIGH_LEVEL        : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"8DB";  --(14V)
--  CONSTANT RE_LOW_LEVEL          : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"3C2";   -- 9VDC    --> Modified for Dragon project P2 test only
--  CONSTANT RE_HIGH_LEVEL         : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"642";   -- 15VDC   --> Modified for Dragon project P2 test only
  CONSTANT RE_LOW_LEVEL          : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"5B1";   -- 9VDC  * 161.8577 --> Modified for LV Drive project LVLC P1 test only
  CONSTANT RE_HIGH_LEVEL         : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"97C";   -- 15VDC * 161.8577 --> Modified for LV Drive project LVLC P1 test only
  
  -- Constants for timers/counters
  CONSTANT NO_OF_ERRORS     : INTEGER := 3;
  CONSTANT NO_OF_DC_SAMPLES : INTEGER := 3;
  CONSTANT INRUSH_TIME_OUT  : INTEGER := 65000;  -- 650 ms  --by Yang
--  CONSTANT INRUSH_TIME_OUT  : INTEGER := 50000;  -- 500 ms  --by Yang
  CONSTANT RELAY_TIME_OUT   : INTEGER := 1500;   -- 15 ms
  CONSTANT BLEEDER_TIME_OUT : INTEGER := 1000;   -- 10 ms
  CONSTANT ONE_HUNDRED_MS   : INTEGER := 10000;  -- 100 ms  

  -- Related to RE voltage supervision (+1 since new adc sample every 2:nd tick)
  SIGNAL cntRe1error : NATURAL RANGE 0 TO NO_OF_ERRORS + 1;
  SIGNAL cntRe2error : NATURAL RANGE 0 TO NO_OF_ERRORS + 1;  
  
  -- Related to DC voltage supervision
  SIGNAL cntDcGuard     : NATURAL RANGE 0 TO NO_OF_DC_SAMPLES + 1;
  SIGNAL dcLevelGuard   : STD_LOGIC;
  SIGNAL dcStable       : STD_LOGIC;
  SIGNAL dcTimer        : NATURAL RANGE 0 TO 159;
  SIGNAL dcRefLevelLow  : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL dcRefLevelHigh : STD_LOGIC_VECTOR(11 DOWNTO 0);  
  
  -- Related to "inrush circuit" statemachine
  SIGNAL relayFailure_i       : STD_LOGIC;
  SIGNAL bleederOpen_i        : STD_LOGIC;
  SIGNAL inrushResistorOpen_i : STD_LOGIC;
  SIGNAL inrushTimer          : NATURAL RANGE 0 TO INRUSH_TIME_OUT;
  SIGNAL inrushActive_i       : STD_LOGIC;
  SIGNAL reOn_i               : STD_LOGIC;
  SIGNAL re1Ok                : STD_LOGIC;
  SIGNAL re2Ok                : STD_LOGIC;
  SIGNAL reOk                 : STD_LOGIC;
  SIGNAL dcRef                : STD_LOGIC_VECTOR(11 DOWNTO 0);
  
  TYPE inrush_t IS (idle, chargeDC, wait100ms_1 ,engageRelays, checkRelays, wait100ms, checkBleeder,
                    inrushDone, disengageRelays, waitForMainsMissing);
  SIGNAL inrushState : inrush_t;

  -- Related to "bleeder resistor"
  SIGNAL bleederOn_i          : STD_LOGIC;
  SIGNAL bleederTestCompleted : STD_LOGIC;

BEGIN

-------------------------------------------------------------------------------
-- Keeping track of DC levels for relay control
-------------------------------------------------------------------------------
  -- The purpose is to avoid erroneous measurement values from the ADCs. The
  -- dcLevelGuard signal change state upon three successive values that crosses 
  -- the defined DC levels for engage respectively disengage relays. The
  -- dcLevelGuard keeps track that we are within permitted VDC range for each of
  -- the different supplies.
  
  monitorDcLevels : PROCESS (clk, rst_n)
  BEGIN
    IF rst_n = '0' THEN
      cntDcGuard   <= 0;
      dcLevelGuard <= '0';
    ELSIF clk'event AND clk = '1' THEN
      IF adcDataUpdated = '1' THEN
        IF dcLevelGuard = '0' THEN
          IF (dcVoltage >= dcEngageLevel) THEN            
            IF cntDcGuard = (NO_OF_DC_SAMPLES + 1) THEN
              dcLevelGuard <= '1';
              cntDcGuard <= 0;
            ELSE
              dcLevelGuard <= dcLevelGuard;
              cntDcGuard <= cntDcGuard + 1;
            END IF;
          ELSE
            cntDcGuard <= 0; 
            dcLevelGuard <= '0';
          END IF;
        ELSIF dcLevelGuard = '1' THEN
          IF (dcVoltage < dcDisengageLevel) THEN            
            IF cntDcGuard = (NO_OF_DC_SAMPLES + 1) THEN
              dcLevelGuard <= '0';
              cntDcGuard <= 0;
            ELSE
              dcLevelGuard <= dcLevelGuard;
              cntDcGuard <= cntDcGuard + 1;
            END IF;
          ELSE
            cntDcGuard <= 0; 
            dcLevelGuard <= '1';
          END IF;
        END IF;
      ELSE
        cntDcGuard <= cntDcGuard;
        dcLevelGuard <= dcLevelGuard;
      END IF;
    END IF;
  END PROCESS monitorDcLevels;
  
-------------------------------------------------------------------------------
-- Keeping track of when DC has been fully charged
-------------------------------------------------------------------------------
  -- Purpose: When the DC ripple during 10 ms are less than or equal to
  -- 3 VDC it is considered that the DC link is fully charged.
  -- A new DC sample is received every 63 us => 159 sample = 10,01 ms
  
  chkIfDcStable : PROCESS (clk, rst_n)
  BEGIN
    IF rst_n = '0' THEN
      dcStable <= '0';
      dcTimer  <= 0;
      dcRefLevelLow  <= (OTHERS => '0');
      dcRefLevelHigh <= (OTHERS => '0');      
    ELSIF clk'event AND clk = '1' THEN
      IF adcDataUpdated = '1' THEN
        IF dcTimer = 0 THEN
          dcRefLevelLow <= dcVoltage;
          dcRefLevelHigh <= dcVoltage;
          dcTimer <= dcTimer + 1;
        ELSIF dcTimer = 5 AND debugMode = '1' THEN
          -- for simulation only
          dcTimer <= 0;
          IF dcRefLevelHigh - dcRefLevelLow <= dcSettleLevel THEN
            dcStable <= '1';
          ELSE
            dcStable <= '0';
          END IF;
        ELSIF dcTimer = 159 THEN          
          dcTimer <= 0;
          IF dcRefLevelHigh - dcRefLevelLow <= dcSettleLevel THEN
            dcStable <= '1';
          ELSE
            dcStable <= '0';
          END IF;
        ELSE
          dcTimer <= dcTimer + 1;          
          IF dcVoltage < dcRefLevelLow THEN
            dcRefLevelLow <= dcVoltage;
          ELSIF dcVoltage >= dcRefLevelHigh THEN
            dcRefLevelHigh <= dcVoltage;
          ELSE
            dcRefLevelLow <= dcRefLevelLow;
            dcRefLevelHigh <= dcRefLevelHigh;            
          END IF;
        END IF;
      END IF;
    END IF;
  END PROCESS chkIfDcStable;

-------------------------------------------------------------------------------
-- Logic to continuously monitor the relay coil voltage at "running mode"
-------------------------------------------------------------------------------
  -- The purpose of this process is to continuously monitor, and if the voltages
  -- is outside permitted window, i.e. reOk is false. In order to avoid 
  -- detecting a false sample due to measurement noise, only at three 
  -- successive erreneous RE voltage samples, it is considered that a relay 
  -- failure effectively has occured.

  reOk <= re1Ok AND re2Ok;
  
  monitorRE: PROCESS (clk, rst_n)
  BEGIN
    IF rst_n = '0' THEN               
      re1Ok <= '0';
      re2Ok <= '0';      
      cntRe1error <= 0;
      cntRe2error <= 0;
    ELSIF clk'event AND clk = '1' THEN
      IF adcDataUpdated = '1' THEN
        IF (re1Voltage >= RE_LOW_LEVEL AND re1Voltage <= RE_HIGH_LEVEL) THEN            
          cntRe1error <= 0;
          re1Ok <= '1';
        ELSE
          IF cntRe1error = (NO_OF_ERRORS + 1) THEN
            re1Ok <= '0';
            cntRe1error <= cntRe1error;
          ELSE
            re1Ok <= re1Ok;
            cntRe1error <= cntRe1error + 1;
          END IF;
        END IF;

        IF (re2Voltage >= RE_LOW_LEVEL AND re2Voltage <= RE_HIGH_LEVEL) THEN            
          cntRe2error <= 0;
          re2Ok <= '1';
        ELSE
          IF cntRe2error = (NO_OF_ERRORS + 1) THEN
            re2Ok <= '0';
            cntRe2error <= cntRe2error;
          ELSE
            re2Ok <= re2Ok;
            cntRe2error <= cntRe2error + 1;
          END IF;
        END IF;
      ELSE
        re1Ok <= re1Ok;
        re2Ok <= re2Ok;        
        cntRe1error <= cntRe1error;
        cntRe2error <= cntRe2error;
      END IF;
    END IF;
  END PROCESS monitorRE;
  
-------------------------------------------------------------------------------
-- Logic to handle INRUSH CIRCUIT STATES, see also flow chart in reference 1.
-------------------------------------------------------------------------------  
   -- Purpose: Control the inrush circuit by means of the relays (reOn). During
   -- startup the inrush circuit is in "charing" state, and when DC is fully
   -- charged and the status of relay, bleeder and inrush resistors are ok,
   -- the "running" state is entered.

  inrushCircuitSM: PROCESS (clk, rst_n)
  BEGIN 
    IF rst_n = '0' THEN
      inrushTimer     <= 0;
      inrushActive_i  <= '1';
      reOn_i          <= '0';
      inrushResistorOpen_i <= '0';
      inrushState     <= idle;
      bleederOpen_i   <= '0';
      relayFailure_i  <= '0';
      dcRef <= (OTHERS => '0');
      bleederTestCompleted <= '0';
    ELSIF clk'event AND clk = '1' THEN

      CASE inrushState IS

        WHEN idle =>
          inrushTimer <= 0;
          relayFailure_i <= '0';
          bleederTestCompleted <= '0';
          IF cfgDone = '1' AND mainsMissing = '0' AND mainsVACType /= "0000" THEN
            inrushState <= chargeDC;
          ELSE
            inrushState <= idle;
          END IF;

        WHEN chargeDC =>
          IF dcLevelGuard = '1' AND dcStable = '1' AND dcTimer = 0 THEN
            inrushTimer <= 0;
            IF bleederTestCompleted = '0' THEN
              inrushState <= checkBleeder;
            ELSE
              inrushState <= wait100ms_1;
            END IF;
          ELSE
            IF clk100KHzEn = '1' THEN
              IF mainsMissing = '1' THEN
                inrushState <= idle;
              ELSIF inrushTimer = 150 AND debugMode = '1' THEN
                -- for simulation only
                inrushState <= waitForMainsMissing;
                inrushResistorOpen_i <= '1';                
              ELSIF inrushTimer = INRUSH_TIME_OUT THEN
                -- 500 ms passed
                inrushState <= waitForMainsMissing;
                inrushResistorOpen_i <= '1';
              ELSE
                inrushState <= chargeDC;
                inrushTimer <= inrushTimer + 1;
              END IF;
            END IF;            
          END IF;

        WHEN checkBleeder =>
          -- Engage bleeder resitor during maximum 10 ms and check if the DC
          -- link voltage drops down to the configurable level "bleederTestLevel"
          IF bleederShortCircuit = '1' THEN
            inrushState <= idle;
          ELSIF bleederVoltage > bleederTestLevel THEN
            inrushState <= chargeDC;                        
            bleederTestCompleted <= '1';
            inrushTimer <= 0;
          ELSE
            IF clk100KHzEn = '1' THEN
              IF inrushTimer = 125 AND debugMode = '1' THEN
                -- for simulation only
                inrushState <= waitForMainsMissing;
                bleederOpen_i <= '1';
              ELSIF inrushTimer = BLEEDER_TIME_OUT THEN
                -- 10 ms passed
                inrushState <= waitForMainsMissing;
                bleederOpen_i <= '1';
              ELSE
                inrushState <= checkBleeder;
                inrushTimer <= inrushTimer + 1;
              END IF;         
            END IF;
          END iF;          

        WHEN wait100ms_1 =>          
          IF clk100KHzEn = '1' THEN
            IF inrushTimer = 15 AND debugMode = '1' THEN
              -- for simulation only
              inrushState <= engageRelays;
              inrushTimer <= 0;
            ELSIF inrushTimer = ONE_HUNDRED_MS THEN
              -- 100 ms passed
              inrushState <= engageRelays;
              inrushTimer <= 0;
            ELSE
              inrushState <= wait100ms_1;
              inrushTimer <= inrushTimer + 1;
            END IF;         
          END IF;
			 
        WHEN engageRelays =>
          -- Switching inrush circuit into "running" state.
          reOn_i <= '1';
          inrushState <= checkRelays;
          
        WHEN checkRelays =>
          IF reOk = '1' THEN 
            -- Both relay voltages are within permitted window
            inrushState <= wait100ms;
            inrushTimer <= 0;
          ELSE
            IF clk100KHzEn = '1' THEN
              IF inrushTimer = 125 AND debugMode = '1' THEN
                -- for simulation only
                inrushState <= waitForMainsMissing;
                relayFailure_i <= '1';                
              ELSIF inrushTimer = RELAY_TIME_OUT THEN
                -- 15 ms passed
                inrushState <= waitForMainsMissing;
                relayFailure_i <= '1';
              ELSE
                inrushState <= checkRelays;
                inrushTimer <= inrushTimer + 1;
              END IF;
            END IF;  
          END IF;
          
        WHEN wait100ms =>          
          IF clk100KHzEn = '1' THEN
            IF inrushTimer = 15 AND debugMode = '1' THEN
              -- for simulation only
              inrushState <= inrushDone;
              inrushTimer <= 0;
            ELSIF inrushTimer = ONE_HUNDRED_MS THEN
              -- 100 ms passed
              inrushState <= inrushDone;
              inrushTimer <= 0;
            ELSE
              inrushState <= wait100ms;
              inrushTimer <= inrushTimer + 1;
            END IF;         
          END IF;
          
        WHEN inrushDone =>
          -- By ending up in this state, all start-up conditions were
          -- fulfilled. Now we are ready to allow PWM.
          inrushActive_i <= '0';
--          IF dcLevelGuard = '0' AND mainsMissing = '1' THEN  --by Yang
          IF mainsMissing = '1' THEN
            -- Conditions fulfilled for disengage relays, i.e. DC_V < dcDisEngageLevel
            -- during three samples AND mains missing for > 100 ms.
            IF clk100KHzEn = '1' THEN
              IF inrushTimer = 15 AND debugMode = '1' THEN
                -- for simulation only
                inrushState <= disengageRelays;
                inrushTimer <= 0;
	      ELSIF inrushTimer = ONE_HUNDRED_MS THEN
                -- 100 ms passed
                inrushState <= disengageRelays;
                inrushTimer <= 0;
              ELSE
                inrushState <= inrushDone;
                inrushTimer <= inrushTimer + 1;
              END IF;         
            END IF;
            -- inrushState <= disengageRelays; CNABB BUG
          ELSIF reOk = '0' THEN
            -- Relay broken during runtime
            relayFailure_i <= '1';              
            inrushTimer <= 0;				
          ELSE
            inrushState <= inrushDone;
            inrushTimer <= 0;
          END IF;

        WHEN disengageRelays =>
          -- Switching inrush circuit into "charging" state. 
          inrushActive_i <= '1';                
          reOn_i <= '0';
          inrushState <= idle;
          
        WHEN waitForMainsMissing =>
          -- An MDU HW error has occured. The error type is reported and the
          -- inrush state machine waits until SW has detected the error and
          -- thus open the contactor which result in "mainsMissing". When
          -- "mainsMissing" is detected, the error bit is cleared.
          IF mainsMissing = '0' THEN
            inrushState    <= waitForMainsMissing;
            bleederOpen_i  <= bleederOpen_i;
            inrushResistorOpen_i <= inrushResistorOpen_i;
            relayFailure_i <= relayFailure_i;
          ELSE
            inrushState    <= idle;
            bleederOpen_i  <= '0';
            inrushResistorOpen_i <= '0';
            relayFailure_i <= '0';
          END IF;
          
        WHEN OTHERS =>
          inrushState <= idle;
          
      END CASE;
    END IF;
  END PROCESS inrushCircuitSM;

-------------------------------------------------------------------------------
-- Logic for BLEEDER control, see also reference 1. 
-------------------------------------------------------------------------------
  -- Purpose: Control when the bleeder resistor shall be engaged in order to
  -- bleed off excessive voltage on the DC link or for test presence of the
  -- resistor at motors on.
  
  bleederCtrl: PROCESS (clk, rst_n)
  BEGIN 
    IF rst_n = '0' THEN
      bleederOn_i <= '0';
    ELSIF clk'event AND clk = '1' THEN
      IF mainsVACType = "0000" THEN
        -- Configuration data not valid
        bleederOn_i <= '0';
      ELSE
        IF dcVoltage > bleederTurnOnLevel THEN
          bleederOn_i <= '1';
        ELSIF dcVoltage < bleederTurnOffLevel THEN
          bleederOn_i <= '0';
        ELSE
          bleederOn_i <= bleederOn_i;
        END IF;        
      END IF;
    END IF;
  END PROCESS bleederCtrl;
 
-------------------------------------------------------------------------------
-- Continuous assignments 
-------------------------------------------------------------------------------
  relayFailure       <= relayFailure_i;
  bleederOpen        <= bleederOpen_i;
  inrushResistorOpen <= inrushResistorOpen_i;
  inrushActive       <= inrushActive_i;
  reOn               <= reOn_i;
  bleederOn          <= bleederOn_i;
  
-------------------------------------------------------------------------------
END ARCHITECTURE rtl;

