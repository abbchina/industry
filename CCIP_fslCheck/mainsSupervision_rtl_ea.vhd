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
-- Title:               Incoming mains supervision unit
-- File name:           mainsSupervision_rtl_ea.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:		1.5
-- Prepared by:		SEROP/PRCB Björn Nyqvist
-- Status:		Approved
-- Date:		2009-01-18
-- **************************************************************************************
-- References:
-- 1. Implementation Specification Rectifier Controller 3HAC030434-001
-- 2. TRS MINK Power and Capacitor Unit 3HAC027503-001
-- 3. EK Gränssnittsbeskrivning rev D
-- **************************************************************************************
-- Functional description:
--
-- Mains supervision by means of the phaseTrig PT signal which pulses low each
-- time a phase crosses zero with a positive derivative. See furhter comments
-- in connection to each process.
--
-- Abbreviations:
-- PT = Period Time (of PhaseTrig pulse)
-- BF = Base Frequency
-- 1P = One phase
-- 3P = Three phases
-- **************************************************************************************
-- Changes:
-- 1.1 080402 BjNy: Make false AC peak detection less sensitive in output stage.
-- 1.2 080411 BjNy: Scale factor of 4.8 on AC_V and DC_V inserted.
-- 1.3 080520 BjNy: Completely updated to conform to MPU P1.1.
-- 1.4 081204 BjNy: phaseError removed and freqError detection inserted.
-- 1.5 090118 BjNy: clk100KhzEn_d removed. 
-- **************************************************************************************
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.numeric_std.ALL;

ENTITY mainsSupervision IS
  PORT(
    rst_n                : IN  STD_LOGIC;
    clk                  : IN  STD_LOGIC;
    clk100KHzEn          : IN  STD_LOGIC;    
    phaseTrig_i          : IN  STD_LOGIC;
    noOfPhases           : IN  STD_LOGIC;
    cfgDone              : IN  STD_LOGIC;
    newAcSampleEnable    : IN  STD_LOGIC;
    mainsVACType         : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
    dcVoltage            : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    acVoltage            : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    dcDisengageLevel     : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);        
    mainsMissing         : OUT STD_LOGIC;
    phaseMissing         : OUT STD_LOGIC;
    freqError            : OUT STD_LOGIC;
    -- Temp added test signals
    acIsCrap             : OUT STD_LOGIC
    );
END mainsSupervision;

ARCHITECTURE rtl OF mainsSupervision IS
  
  -- Related to phase missing supervision:  
  SIGNAL phaseMissing_i    : STD_LOGIC;
  
  --------------------------------------------------------
  --
  --------------------------------------------------------

--  CONSTANT LV_ACDETECT_LEVEL : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"470";   -- 141 AC_Vpeak * 8.06102  --> Modified for Dragon project P2 test only
--  CONSTANT LV_PHASE_DIFF_LEVEL : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"919"; -- 289 AC_Vpeak * 8.06102  --> Modified for Dragon project P2 test only
  CONSTANT LV_ACDETECT_LEVEL : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"366";   -- 141 AC_Vpeak * 6.173677 --> Modified for LV Drive project LVLC P1 test only
  CONSTANT LV_PHASE_DIFF_LEVEL : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"6F8"; -- 289 AC_Vpeak * 6.173677 --> Modified for LV Drive project LVLC P1 test only
  
  -- Related to "detect peak AC_V" process
  SIGNAL acPeakHigh              : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL acPeakLow               : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL acPeakHigh_i1           : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL acPeakLow_i1            : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL acPeakHigh_i2           : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL acPeakLow_i2            : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL lowestValueOfAcPeakHigh : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL highestValueOfAcPeakLow : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL cnt                     : NATURAL;
  SIGNAL cntHigh                 : NATURAL;
  SIGNAL cntLow                  : NATURAL;

  TYPE peakDetect_t IS (idle, waitOnACsampleHigh, storeAcPeakHigh, waitOnACsampleLow, storeAcPeakLow, outputAcPeak);
  SIGNAL peakDetectState : peakDetect_t;

  -- Related to "detect incoming mains" process
  SIGNAL mainsMissing_i  : STD_LOGIC;
  SIGNAL lvMainsDetected        : STD_LOGIC;
  SIGNAL hvMainsDetected        : STD_LOGIC;
  SIGNAL hvMains20msThreshold_i : STD_LOGIC;
  SIGNAL cntACdip               : NATURAL;  

  TYPE mainsMissing_t IS (idle, mainsOk, dipFound);
  SIGNAL mainsMissingState : mainsMissing_t;
  
  -- Related to hvSupply detection
  SIGNAL mainsMissing_d : STD_LOGIC;
  SIGNAL hvSupply_i     : STD_LOGIC;
  
  -- Related to "detect missing phase" process
  SIGNAL allPhasesOk    : STD_LOGIC;
  SIGNAL cntPhaseDip    : NATURAL;
  
  TYPE phaseMissing_t IS (idle, phasesOk, dipFound);
  SIGNAL phaseMissingState : phaseMissing_t;

BEGIN
  
------------------------------------------------------------------------------
------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- See "DETECT PEAK AC_V" chapter in reference 1.
-------------------------------------------------------------------------------  
  -- Purpose: As soos as the rectifier controller is configured by the DSP,
  -- this process continuously searching the highest AC_V and lowest AC_V
  -- respectively. When three successive AC_V is lower than stored highest
  -- AC_V, we have found a high peak of AC_V. The opposite applies for finding
  -- low peak AC_V. In case of stored peak value happens to be a transient, the
  -- two highest values and the two lowest values are disregarded for high and 
  -- low peaks respectively. This implies we consider 3 AC top peaks and 3 low
  -- peaks of the AC ripple before the filtered AC value is output, which
  -- yields a throuhput of 10 ms.
  -- The statemachine expects to find rising values on AC_V at startup.
  -- However, at startup we dont know if this is case. The two first AC peak
  -- values might therfore be false, this is handled by the outputACPeak stage.
  
  calcPeakAC_SM: PROCESS (clk, rst_n)
  BEGIN  
    IF rst_n = '0' THEN
      cnt                     <= 0;
      cntHigh                 <= 0;
      cntlow                  <= 0;
      peakDetectState         <= idle;
      acIsCrap                <= '0';
      lowestValueOfAcPeakHigh <= (OTHERS => '1');
      highestValueOfAcPeakLow <= (OTHERS => '0');
      acPeakHigh_i1           <= (OTHERS => '0');
      acPeakLow_i1            <= (OTHERS => '0');
      acPeakHigh_i2           <= (OTHERS => '0');
      acPeakLow_i2            <= (OTHERS => '0');
      acPeakHigh              <= (OTHERS => '0');
      acPeakLow               <= (OTHERS => '0');
    ELSIF clk'event AND clk = '1' THEN
      CASE peakDetectState IS
        
        WHEN idle =>
          acIsCrap <= '0';
          IF cfgDone = '1' THEN
            peakDetectState <= waitOnACsampleHigh;
          ELSE
            peakDetectState <= idle;
          END IF;

        WHEN waitOnACsampleHigh =>
          IF newAcSampleEnable = '1' THEN
            IF acVoltage > acPeakHigh_i1 THEN
              cnt <= 0;
              acPeakHigh_i1 <= acVoltage;
            ELSE
              IF cnt = 2 THEN
                -- Three successive lower AC is detected
                peakDetectState <= storeAcPeakHigh;
              ELSE
                cnt <= cnt + 1;
              END IF;
            END IF;
          END IF;
          
        WHEN storeAcPeakHigh =>
          cnt <= 0;
          acPeakLow_i1    <= acVoltage;  -- Assign next starting point
          peakDetectState <= waitOnACsampleLow;

          -- Select the lowest ACpeakHigh out of three "high" peaks.
          IF cntHigh = 2 THEN           -- Three AC high peaks now included
            cntHigh  <= 0;
            IF acPeakHigh_i1 < lowestValueOfAcPeakHigh THEN
              acPeakHigh_i2 <= acPeakHigh_i1;
            ELSE
              acPeakHigh_i2 <= lowestValueOfAcPeakHigh;
            END IF;
          ELSE
            -- Still AC high peaks left
            cntHigh <= cntHigh + 1;
            IF acPeakHigh_i1 < lowestValueOfAcPeakHigh THEN
              lowestValueOfAcPeakHigh <= acPeakHigh_i1;
            ELSE
              -- do nothing, i.e. disregard acPeakHigh_i1 since it is not the
              -- lowest value so far of the three actual AC high peaks.
              lowestValueOfAcPeakHigh <= lowestValueOfAcPeakHigh;
            END IF;
          END IF;
      
        WHEN waitOnACsampleLow =>
          IF newAcSampleEnable = '1' THEN
            IF acVoltage < acPeakLow_i1 THEN
              cnt <= 0;
              acPeakLow_i1 <= acVoltage;
            ELSE
              IF cnt = 2 THEN
                -- Three successive higher AC is detected
                peakDetectState <= storeAcPeakLow;
              ELSE
                cnt <= cnt + 1;
              END IF;
            END IF;
          END IF;

        WHEN storeAcPeakLow =>
          cnt <= 0;
          acPeakHigh_i1 <= acVoltage;  -- Assign next starting point
  
          -- Select the highest ACpeakLow out of three "low" peaks.
          IF cntLow = 2 THEN             -- Three AC low peaks now included
            peakDetectState <= outputAcPeak;
            cntLow <= 0;
            lowestValueOfAcPeakHigh <= (OTHERS => '1');  -- Prepare for next cycle
            highestValueOfAcPeakLow <= (OTHERS => '0');  -- Prepare for next cycle
      
            IF acPeakLow_i1 > highestValueOfacPeakLow THEN
              acPeakLow_i2 <= acPeakLow_i1;
            ELSE
              acPeakLow_i2 <= highestValueOfAcPeakLow;
            END IF;
          ELSE
            -- Still AC low peaks left
            peakDetectState <= waitOnACsampleHigh;            
            cntLow <= cntLow + 1;
            IF acPeakLow_i1 > highestValueOfacPeakLow THEN
              highestValueOfacPeakLow <= acPeakLow_i1;
            ELSE
              -- do nothing, i.e. disregard acPeakLow_i1 since it is not the
              -- highest value so far of the three actual AC low peaks.
              highestValueOfacPeakLow <= highestValueOfacPeakLow;
            END IF;
          END IF;

        WHEN outputAcPeak =>
          peakDetectState <= waitOnACsampleHigh;
          acIsCrap <= '0';            -- debug status signal

          -- This stage is enterered every 10 ms = 3 periods of 300Hz.
          IF acPeakHigh_i2 > acPeakLow_i2 THEN
            ACpeakHigh <= acPeakHigh_i2;
            ACpeakLow  <= acPeakLow_i2;
          ELSE
            -- Handle false values which might occur if AC_V is very noisy or
            -- when incoming mains is off.
            acIsCrap <= '1';            -- debug status signal
            IF acVoltage(11 DOWNTO 9) = "000" THEN
              -- Incoming mains is disengaged = off
              ACpeakHigh <= (OTHERS => '0');
              ACpeakLow  <= (OTHERS => '0');
            ELSE
              -- Due to a noisy AC_V this algorithm has detected a local peak
              -- which resulted in this state and thus disregard actual values
              -- until next valid values is found.
              ACpeakHigh <= ACpeakHigh;
              ACpeakLow  <= ACpeakLow; 
            END IF;
          END IF;

        WHEN OTHERS =>  
          peakDetectState <= idle;
          
      END CASE;
    END IF;
  END PROCESS calcPeakAC_SM;
  
-------------------------------------------------------------------------------
-- See "DETECTECTION OF INCOMING MAINS" chapter in reference 1.
-------------------------------------------------------------------------------  
  -- Purpose: Simply to check that the mains contactor has been engaged
  -- regardless of having a LV or HV system. If AC_V is higher than 141V, it is 
  -- considered that incoming mains is detected.
  -- The "hvMainsDetected" is only used for the "disengage relay" function.
  -- See also handleACDips statemachine.

  detectIncomingMains: PROCESS (clk, rst_n)
  BEGIN  
    IF rst_n = '0' THEN
      lvMainsDetected <= '0';
      hvMainsDetected <= '0';      
    ELSIF clk'event AND clk = '1' THEN
      IF acPeakHigh > LV_ACDETECT_LEVEL THEN         -- LV AC_Vpeak > 141V
        lvMainsDetected <= '1';
      ELSE
        lvMainsDetected <= '0';                                 
      END IF;
    END IF;
  END PROCESS detectIncomingMains;

-------------------------------------------------------------------------------
-- See "DIPS ON INCOMING MAINS" and "DISENGAGE RELAYS" chapters in reference 1.
-------------------------------------------------------------------------------  
  -- Purpose: Dips up to 20 ms are allowed on incoming mains which is handled
  -- in this process, i.e. 'mainsMissing' is set upon a AC dip > 20 ms.
  --
  -- In addition, one condition for disengage relays for HV supply is 
  -- AC_V(HV) < 283V for > 20 ms, this is controlled by 'hvMains20msThreshold' 
  -- also defined in this process since it is connected to the function of
  -- mainsMissing.
  -- Furthermore, the condition for disengage the relays for LV supply is
  -- defined equally as mainsMissing. Thus, mainsMissing is used to control
  -- disengagement of relays if LV supply is used.


  handleACDips_SM : PROCESS (clk, rst_n)
  BEGIN
    IF rst_n = '0' THEN
      mainsMissingState <= idle;
      mainsMissing_i <= '1';
      cntACdip <= 0;
      hvMains20msThreshold_i <= '0';
    ELSIF clk'event AND clk = '1' THEN

      CASE mainsMissingState IS

        WHEN idle =>
          mainsMissing_i <= '1';
          hvMains20msThreshold_i <= hvMains20msThreshold_i;

          IF lvMainsDetected = '1' THEN
            mainsMissingState <= mainsOk;
          ELSE
            mainsMissingState <= idle;
          END IF;
              
        WHEN mainsOk =>
          mainsMissing_i <= '0';
          hvMains20msThreshold_i <= '0';

          IF lvMainsDetected = '0' THEN
            mainsMissingState <= dipFound;
          ELSE
            mainsMissingState <= mainsOk;
          END IF;
              
        WHEN dipFound =>
          IF lvMainsDetected = '0' THEN
            IF cntACdip = 2000000 THEN
              --IF cntACdip = 200 THEN   -- FOR DEBUG ONLY
              -- Dip of 20 ms detected
              cntACdip <= 0;
              mainsMissingState <= idle;
            ELSE
              cntACdip <= cntACdip + 1;
            END IF;
          ELSE
            mainsMissingState <= mainsOk;
            cntACdip <= 0;
          END IF;
            
        WHEN OTHERS =>
          mainsMissingState <= idle;
          
      END CASE;
    END IF;
  END PROCESS handleACDips_SM;

-------------------------------------------------------------------------------
--  See "DETECT MISSING PHASE" chapter in reference 1.
-------------------------------------------------------------------------------
  -- Purpose: A missing phase is allowed up to 20 ms on incoming mains which is 
  -- handled in this section, i.e. 'phaseMissing' is set upon a AC phase dip 
  -- which lasts longer than 20 ms.

  detectMissingPhases: PROCESS (clk, rst_n)
  BEGIN
    IF rst_n = '0' THEN
      allPhasesOk <= '0';
    ELSIF clk'event AND clk = '1' THEN 
      IF mainsMissing_i = '0' THEN
          -- For LV supply
          IF acPeakHigh - acPeakLow > LV_PHASE_DIFF_LEVEL THEN
            IF noOfPhases = '0' THEN
              allPhasesOk <= '0';  -- detect phase missing when inCommingMain is 3phase
            ELSE
              allPhasesOk <= '1'; -- do not report phase missing when inCommingMain is 1phase
            END IF;
          ELSE
            allPhasesOk <= '1';
          END IF;
      ELSE
        allPhasesOk <= '0';
      END IF;      
    END IF;
  END PROCESS detectMissingPhases;

  handlePhaseDips_SM : PROCESS (clk, rst_n)
  BEGIN
    IF rst_n = '0' THEN
      phaseMissingState <= idle;
      phaseMissing_i <= '1';
      cntPhaseDip <= 0;
    ELSIF clk'event AND clk = '1' THEN
      
      CASE phaseMissingState IS

        WHEN idle =>
          phaseMissing_i <= '1';
          
          IF allPhasesOk = '1' THEN
            phaseMissingState <= phasesOk;
          ELSE
            phaseMissingState <= idle;
          END IF;

        WHEN phasesOk =>
          phaseMissing_i <= '0';
          
          IF mainsMissing_i = '1' THEN
            phaseMissingState <= idle;
          ELSIF allPhasesOk = '0' THEN
            phaseMissingState <= dipFound;
          ELSE
            phaseMissingState <= phasesOk;
          END IF;

        WHEN dipFound =>
          IF mainsMissing_i = '1' THEN
            phaseMissingState <= idle;
          ELSIF allPhasesOk = '0' THEN
            IF cntPhaseDip = 2000000 THEN
            --IF cntPhaseDip = 200 THEN   -- FOR DEBUG ONLY
              -- Dip of 20 ms detected
              cntPhaseDip <= 0;
              phaseMissingState <= idle;
            ELSE
              cntPhaseDip <= cntPhaseDip + 1;
            END IF;
          ELSE
            phaseMissingState <= phasesOk;
          END IF;
            
        WHEN OTHERS =>
          phaseMissingState <= idle;

      END CASE;
    END IF;
  END PROCESS handlePhaseDips_SM;

  
-------------------------------------------------------------------------------
-- Continuous assignments 
-------------------------------------------------------------------------------
phaseMissing <= phaseMissing_i;
mainsMissing <= mainsMissing_i;
freqError    <= '0';
-------------------------------------------------------------------------------
END ARCHITECTURE rtl;
