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
-- Title:               Request Manager unit
-- File name:           reqMgr_rtl_a.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:		0.1
-- Prepared by:		SEROP/PRCB Björn Nyqvist
-- Status:		First version
-- Date:		2008-11-08
-- **************************************************************************************
-- References:
-- 1. Datasheet ST M95512-R 512Kbit Serial SPI EEPROM
-- 2. Datasheet Numonyx M25P80 8Mbit Serial SPI Flash
-- 3. IS - memCtrl unit in R19/R21 3HAC TBD
-- **************************************************************************************
-- Functional description:
--
-- The purpose of the request manager is to handle different types of
-- requests issued either by the Mailbox interface unit or the ESM unit.
--
-- Three different kinds of requests are performed:
-- req1 = start to select a specific flash device selected by "flashToSel"
-- reg2 = start to read out the "ValidFlag" byte from flash2 and verify the contents
-- req3 = start to select either flash 2 or eeprom selected by "memSel"
--
-- flashToSel: 0 = flash1 / 1 = flash2
-- memSel    : 0 = flash2 / 1 = eeprom
-- **************************************************************************************
-- changes:
-- 1.1 
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.numeric_std.ALL;

ENTITY reqMgr IS
  PORT(
    rst_n                : IN  STD_LOGIC;
    clk                  : IN  STD_LOGIC;
    -- ESM
    flashToSel           : IN  STD_LOGIC;
    startFlashSelect     : IN  STD_LOGIC;
    flashSelectDone      : OUT STD_LOGIC;
    startFlashValidCheck : IN  STD_LOGIC;
    flashValidCheckDone  : OUT STD_LOGIC;
    flashValidFlagOk     : OUT STD_LOGIC;
    -- mbxIf
    startCheckValidFlag  : OUT STD_LOGIC;
    validFlagStatus      : IN  STD_LOGIC;
    validFlagCheckDone   : IN  STD_LOGIC;
    startMemSelect       : IN  STD_LOGIC;
    memSel               : IN  STD_LOGIC;
    memSelectDone        : OUT STD_LOGIC;
    -- External flip flop
    flashSelect          : OUT STD_LOGIC;
    flashSelectMirror    : IN  STD_LOGIC;
    -- Memory type selection control:
    enableFlashEeprom_n  : OUT STD_LOGIC    
    );
END reqMgr;

ARCHITECTURE rtl OF reqMgr IS


  -- Related to mbx state machine

  TYPE MEM_CTRL_STATE_TYPE IS (waitForReq, evaluateReqNo, disableFlash, disableEeprom, checkFFstatus, generateFFedge,
                               checkReqNo, invokeMbxIf, waitForMbxIfDone, sendAck2MbxIf, sendAck2Esm);
  SIGNAL memCtrlState      : MEM_CTRL_STATE_TYPE;
  SIGNAL flashToSel_i      : STD_LOGIC;
  SIGNAL reqNo             : NATURAL RANGE 0 TO 3;
  SIGNAL edgeCnt           : NATURAL RANGE 0 TO 51;
  SIGNAL validFlagStatus_i : STD_LOGIC;
  SIGNAL flashSelect_i     : STD_LOGIC;  
  SIGNAL memSel_i          : STD_LOGIC;    
  
BEGIN

-------------------------------------------------------------------------------
-- Request Manager state machine
-------------------------------------------------------------------------------
  -- Purpose: Detect incoming requests in order to select correct memory device
  -- for coming operations. Further, a request is sent to mbx if to check if
  -- the valid flag is set in flash 2.


  reqMgrSM : PROCESS (clk, rst_n)
   BEGIN
     IF rst_n = '0' THEN
       memCtrlState <= waitForReq;
       flashToSel_i <= '0';
       reqNo <= 0;
       flashSelectDone <= '0';
       flashValidCheckDone <= '0';
       startCheckValidFlag <= '0';       
       validFlagStatus_i <= '0';
       flashValidFlagOk <= '0';
       memSelectDone <= '0';       
       flashSelect_i <= '0'; --aoi
       edgeCnt <= 0;
       enableFlashEeprom_n <= '1';
       memSel_i <= '0';
     ELSIF clk'event AND clk = '1' THEN
       CASE memCtrlState IS

         WHEN waitForReq =>
           flashSelectDone <= '0';
           flashValidCheckDone <= '0';
           validFlagStatus_i <= '0';
           flashValidFlagOk <= '0';
           memSelectDone <= '0';
           edgeCnt <= 0;
           reqNo <= 0;

           IF startFlashSelect = '1' THEN
             reqNo <= 1;
             flashToSel_i <= flashToSel;
             memCtrlState <= evaluateReqNo;
           ELSIF startFlashValidCheck = '1' THEN
             reqNo <= 2;
             flashToSel_i <= flashToSel;
             memCtrlState <= evaluateReqNo;
           ELSIF startMemSelect = '1' THEN
             reqNo <= 3;
             memSel_i <= memSel;
             flashToSel_i <= '1';
             memCtrlState <= evaluateReqNo;
           ELSE
             memCtrlState <= waitForReq;
           END IF;

         WHEN evaluateReqNo =>
           IF reqNo = 1 OR reqNo = 2 THEN
             memCtrlState <= disableEeprom;
           ELSE
             IF memSel_i = '0' THEN
               memCtrlState <= disableEeprom;
             ELSE
               memCtrlState <= disableFlash;
             END IF;
           END IF;

         WHEN disableFlash =>
           memCtrlState <= sendAck2MbxIf;
           enableFlashEeprom_n <= '0';

         WHEN disableEeprom =>
           memCtrlState <= checkFFstatus;
           enableFlashEeprom_n <= '1';

         WHEN checkFFstatus =>
           IF flashToSel_i = flashSelectMirror THEN
             IF reqNo = 1 THEN
               memCtrlState <= sendAck2Esm;
             ELSIF reqNo = 2 THEN
               memCtrlState <= invokeMbxIf;
             ELSE
               memCtrlState <= sendAck2MbxIf;
             END IF;
           ELSE
             memCtrlState <= generateFFedge;
           END IF;

         WHEN generateFFedge =>
           memCtrlState <= generateFFedge;
           edgeCnt <= edgeCnt + 1;
           IF edgeCnt = 0 THEN
             -- Generate positive edge to Flip Flop
             flashSelect_i <= '1';
           ELSIF edgeCnt = 25 THEN
             -- Generate negative edge to Flip Flop             
             flashSelect_i <= '0';
           ELSIF edgeCnt = 50 THEN
             -- Waited another 250 ns due to Flip Flop
             -- internal propagation delay
				 flashSelect_i <= '0'; --aoi
             memCtrlState <= checkFFstatus;
             edgeCnt <= 0;
           ELSE
             flashSelect_i <= flashSelect_i;
           END IF;

         WHEN invokeMbxIf =>
           memCtrlState <= waitForMbxIfDone;
           startCheckValidFlag <= '1';

         WHEN waitForMbxIfDone =>
           startCheckValidFlag <= '0';
           IF validFlagCheckDone = '1' THEN
             memCtrlState <= sendAck2Esm;
             validFlagStatus_i <= validFlagStatus;
           ELSE
             memCtrlState <= waitForMbxIfDone;
           END IF;

         WHEN sendAck2MbxIf =>
           memCtrlState <= waitForReq;
           memSelectDone <= '1';

         WHEN sendAck2Esm =>
           memCtrlState <= waitForReq;
           IF reqNo = 1 THEN
             flashSelectDone <= '1';
           ELSE
             --reqNo = 2
             flashValidCheckDone <= '1';
             flashValidFlagOk <= validFlagStatus_i;
           END IF;

         WHEN OTHERS =>
           memCtrlState <= waitForReq;

       END CASE;
     END IF;
   END PROCESS reqMgrSM;
   
-------------------------------------------------------------------------------
-- Continuous assignments 
-------------------------------------------------------------------------------
flashSelect <= flashSelect_i;
   
END ARCHITECTURE rtl;

