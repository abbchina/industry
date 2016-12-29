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
-- Title:               Configuration unit
-- File name:           cfgUnit_rtl_a.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:		0.4
-- Prepared by:		SEROP/PRCB Björn Nyqvist
-- Status:		Edited
-- Date:		2008-12-08
-- **************************************************************************************
-- References:
--
-- **************************************************************************************
-- Functional description:
--
-- **************************************************************************************
-- changes:
-- 0.2 Magnus Tysell 081126: Changed the "sdoType" from X"0" to X"5" in evaluate irq state.
-- 0.3 Björn Nyqvist 081203: bleederTestLevel added
-- 0.4 Magnus Tysell PRCB - 081208:
-- * wdtTimeoutInterval changed to 16bits. To be able to use the same time base 10ns as 
-- for other parameters.
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.numeric_std.ALL;

ENTITY cfgUnit IS
  PORT(
    rst_n               : IN  STD_LOGIC;
    clk                 : IN  STD_LOGIC;
    -- mbx unit 
    mbxIrq              : IN  STD_LOGIC;
    sdoType             : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
    rdDataReq           : OUT STD_LOGIC;
    rdAddr              : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    rdData              : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
    rdDataValid         : IN  STD_LOGIC;
    wrDataReq           : OUT STD_LOGIC;
    wrAddr              : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    wrData              : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    wrDataBusy          : IN  STD_LOGIC;
    sdoOpCompleted      : OUT STD_LOGIC;
    sdoOpError          : OUT STD_LOGIC;
    -- Configuration signals:
    cfgDone             : OUT STD_LOGIC;
    maxNoOfLostFrames   : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    mduProtocolVersion  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    bleederTurnOnLevel  : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    bleederTurnOffLevel : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    bleederTestLevel    : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    dcSettleLevel       : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    dcEngageLevel       : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    dcDisengageLevel    : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    mainsVACType        : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    noOfPhases          : OUT STD_LOGIC;
    deadTimeInverter1   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    deadTimeInverter2   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    deadTimeInverter3   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    deadTimeInverter4   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    deadTimeInverter5   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    deadTimeInverter6   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    wdtTimeout          : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    wdtTimeoutInterval  : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
END cfgUnit;

ARCHITECTURE rtl OF cfgUnit IS

  -- Related to main state machine
  TYPE CFG_STATE_TYPE IS (waitForIrq, evaluateIrq, issueRdReq, waitForRdValid);
  SIGNAL cfgState    : CFG_STATE_TYPE;
  SIGNAL sdoType_i   : STD_LOGIC_VECTOR(3 DOWNTO 0);
  SIGNAL rdAddr_i    : STD_LOGIC_VECTOR(4 DOWNTO 0);  

  
BEGIN
  
-------------------------------------------------------------------------------
-- Read cfg data state machine
-------------------------------------------------------------------------------
  -- Purpose: Detect incoming interrupt and reqest configuration data from the
  -- mailbox unit. As all data are read, set cfgDone to notify that the
  -- configuration cycle has completed and thus the FPGA is ready to supervise
  -- the incoming mains etc.

  cfgSM : PROCESS (clk, rst_n)
   BEGIN
     IF rst_n = '0' THEN
       cfgState <= waitForIrq;
       sdoType_i <= (OTHERS => '0');
       sdoOpCompleted <= '0';
       sdoOpError <= '0';       
       cfgDone <= '0';
       noOfPhases <= '0';       
       rdDataReq <= '0';
       rdAddr_i <= (OTHERS => '0');
       rdAddr <= (OTHERS => '0');
       wrDataReq <= '0';       
       wrAddr <= (OTHERS => '0');       
       wrData <= (OTHERS => '0');       
       maxNoOfLostFrames   <= (OTHERS => '0');
       mduProtocolVersion  <= (OTHERS => '0');
       bleederTurnOnLevel  <= (OTHERS => '0');
       bleederTurnOffLevel <= (OTHERS => '0');
       bleederTestLevel    <= (OTHERS => '0');       
       dcSettleLevel       <= (OTHERS => '0');
       dcEngageLevel       <= (OTHERS => '0');
       dcDisengageLevel    <= (OTHERS => '0');
       mainsVACType        <= (OTHERS => '0');
       deadTimeInverter1   <= (OTHERS => '0');
       deadTimeInverter2   <= (OTHERS => '0');
       deadTimeInverter3   <= (OTHERS => '0');
       deadTimeInverter4   <= (OTHERS => '0');
       deadTimeInverter5   <= (OTHERS => '0');
       deadTimeInverter6   <= (OTHERS => '0');
       wdtTimeout          <= (OTHERS => '0');
       wdtTimeoutInterval  <= (OTHERS => '0');
     ELSIF clk'event AND clk = '1' THEN
       
       CASE cfgState IS

         WHEN waitForIrq =>
           sdoOpCompleted <= '0';
           rdAddr_i <= (OTHERS => '0');
           
           IF mbxIrq = '1' THEN
             cfgState <= evaluateIrq;
             sdoType_i <= sdoType;
           ELSE
             cfgState <= waitForIrq;
           END IF;
         
         WHEN evaluateIrq =>
           IF sdoType_i = "0101" THEN
             cfgState <= issueRdReq;
           ELSE
             -- cfg unit not addressed
             cfgState <= waitForIrq;
           END IF;

         WHEN issueRdReq =>
           rdDataReq <= '1';
           rdAddr <= "0000000" & rdAddr_i;
           cfgState <= waitForRdValid;

         WHEN waitForRdValid =>
           rdDataReq <= '0';
           IF rdDataValid = '1' THEN
         
             CASE rdAddr_i IS
               WHEN "00000" =>
                 maxNoOfLostFrames <= rdData(3 DOWNTO 0);
               WHEN "00001" =>
                 mduProtocolVersion <= rdData(7 DOWNTO 0);
               WHEN "00010" =>
                 bleederTurnOnLevel <= rdData(11 DOWNTO 0);
               WHEN "00011" =>
                 bleederTurnOffLevel <= rdData(11 DOWNTO 0);
               WHEN "00100" =>
                 bleederTestLevel    <= rdData(11 DOWNTO 0);
               WHEN "00101" =>
                 dcSettleLevel <= rdData(11 DOWNTO 0);
               WHEN "00110" =>
                 dcEngageLevel <= rdData(11 DOWNTO 0);
               WHEN "00111" =>
                 dcDisengageLevel <= rdData(11 DOWNTO 0);
               WHEN "01000" =>
                 mainsVACType <= rdData(3 DOWNTO 0);
               WHEN "01001" =>
                 noOfPhases <= rdData(0);
               WHEN "01010" =>
                 deadTimeInverter1 <= rdData(11 DOWNTO 0);
               WHEN "01011" =>
                 deadTimeInverter2 <= rdData(11 DOWNTO 0);
               WHEN "01100" =>
                 deadTimeInverter3 <= rdData(11 DOWNTO 0);
               WHEN "01101" =>
                 deadTimeInverter4 <= rdData(11 DOWNTO 0);
               WHEN "01110" =>
                 deadTimeInverter5 <= rdData(11 DOWNTO 0);
               WHEN "01111" =>
                 deadTimeInverter6 <= rdData(11 DOWNTO 0);
               WHEN "10000" =>
                 wdtTimeout <= rdData(11 DOWNTO 0);
               WHEN "10001" =>
                 wdtTimeoutInterval <= rdData;
               WHEN OTHERS => NULL;
             END CASE;

             IF rdAddr_i(4 DOWNTO 0) = "10001" THEN
               cfgState <= waitForIrq;
               cfgDone <= '1';
               sdoOpCompleted <= '1';
             ELSE
               cfgState <= issueRdReq;
               rdAddr_i <= rdAddr_i + '1';
             END IF;
             
           ELSE
             cfgState <= waitForRdValid;
           END IF;
           
         WHEN OTHERS =>
           cfgState <= waitForIrq;
           
       END CASE;
     END IF;
   END PROCESS cfgSM;
   
-------------------------------------------------------------------------------
   
END ARCHITECTURE rtl;

