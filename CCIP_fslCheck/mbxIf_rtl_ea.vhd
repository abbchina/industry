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
-- Title:               Mailbox interface
-- File name:           mbxIf_rtl_a.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:		0.1
-- Prepared by:		SEROP/PRCB Björn Nyqvist
-- Status:		First version
-- Date:		2008-11-12
-- **************************************************************************************
-- References:
-- 1. Datasheet ST M95512-R 512Kbit Serial SPI EEPROM
-- 2. Datasheet Numonyx M25P80 8Mbit Serial SPI Flash
-- 3. IS - SPI unit in R19/R21 3HAC TBD
-- 4. IS - memCtrl unit in R19/R21 3HAC TBD
-- **************************************************************************************
-- Functional description:
--
-- The mailbox interface provides and interface between the SPI unit and the
-- mailbox unit.
--
-- Upon an interrupt from the Mailbox unit, two data packets of 16 bits are fetched into
-- a data buffer "txBuffer". The SPI unit is invoked and upon request from SPI
-- unit "appDataReq" a new data word is read from Mailbox unit. SPI unit reads
-- one byte at the time.
--
-- During ongoing operation, the SPI unit might enter "spiRdInProgress" which
-- means that it reads data from a memory and thus it will request "spiDataUpd"
-- to write the data into the "rxbuffer" to be sent to the Mailbox unit.
--
-- memSel    : 0 = flash2 / 1 = eeprom
-- **************************************************************************************
-- changes:
-- 1.1 
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.numeric_std.ALL;

ENTITY mbxIf IS
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
    sdoOpError          : OUT STD_LOGIC;
    sdoOpErrorCode      : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);    
    -- reqMgr
    startCheckValidFlag : IN  STD_LOGIC;
    validFlagStatus     : OUT STD_LOGIC;
    validFlagCheckDone  : OUT STD_LOGIC;
    startMemSelect      : OUT STD_LOGIC;
    memSel              : OUT STD_LOGIC;
    memSelectDone       : IN  STD_LOGIC;
    -- SPI unit
    spiIrq              : OUT STD_LOGIC;
    sdoOpCompleted      : IN  STD_LOGIC;
    -- SPI TX data, i.e. transmitted to SPI
    appData             : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    appDataAddr         : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
    appDataReq          : IN  STD_LOGIC;
    -- SPI RX data, i.e. received from SPI
    spiData             : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
    spiDataAddr         : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);    
    spiDataUpd          : IN  STD_LOGIC;
    spiDataDone         : IN  STD_LOGIC;
    spiRdInProgress     : IN  STD_LOGIC    
    );
END mbxIf;

ARCHITECTURE rtl OF mbxIf IS

  CONSTANT WR_INSTR : STD_LOGIC_VECTOR(7 DOWNTO 0) := X"02";
  CONSTANT RD_INSTR : STD_LOGIC_VECTOR(7 DOWNTO 0) := X"03";
  CONSTANT SE_INSTR : STD_LOGIC_VECTOR(7 DOWNTO 0) := X"D8";    

  -- Related to mbx state machine
  TYPE MBX_STATE_TYPE IS (waitForIrq, evaluateIrq, sendReq, waitForAck, runBuffMgr);
  SIGNAL mbxState          : MBX_STATE_TYPE;
  SIGNAL startBuffmgr      : STD_LOGIC;
  SIGNAL sdoType_i         : STD_LOGIC_VECTOR(3 DOWNTO 0);
  SIGNAL checkValidFlag    : STD_LOGIC; 
  SIGNAL memSel_i          : STD_LOGIC; 
  
  -- Related to buffer manager "buffMgr" state machine
  TYPE BUFF_MGR_STATE_TYPE IS (startState, preloadTX, sendSpiIrq, evaluateInstruction,
                               waitForSpiRdReq, rdFromMbxUnit, waitForRdValid,
                               waitForSpiWrReq, wrToMbxUnit, sendAckToReqMgr);
  SIGNAL buffMgrState     : BUFF_MGR_STATE_TYPE;
  SIGNAL buffMgrState_d   : BUFF_MGR_STATE_TYPE;
  SIGNAL nextBuffMgrState : BUFF_MGR_STATE_TYPE;
  SIGNAL checkValidFlag_i : STD_LOGIC;
  SIGNAL preloadDone      : STD_LOGIC;  
  SIGNAL addrIsPadded     : STD_LOGIC;  
  SIGNAL index            : STD_LOGIC_VECTOR(1 DOWNTO 0);
  SIGNAL appDataReq_d     : STD_LOGIC;
  SIGNAL rdAddr_i         : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL wrAddr_i         : STD_LOGIC_VECTOR(11 DOWNTO 0);

  TYPE databuffer_t IS ARRAY (0 TO 3) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL txBuffer  : dataBuffer_t;
  SIGNAL rxBuffer  : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL tmpBuffer : STD_LOGIC_VECTOR(7 DOWNTO 0);    

  -- The validFlagBuffer is preloaded with header, instruction and address in
  -- order to perform a read at addr 0xFFFFF0 where read "valid flag" byte is
  -- written if actual flash contains a valid firmware image. The last two
  -- bytes are a "dummy bytes".
  TYPE readValidFlagbuffer_t IS ARRAY (0 TO 7) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL validFlagBuffer : readValidFlagbuffer_t := (X"10", X"04", X"03", X"FF", X"FF", X"F0", X"00", X"00");

BEGIN
  
-------------------------------------------------------------------------------
-- Mailbox interface main state machine
-------------------------------------------------------------------------------
  -- Purpose: Detect incoming interrupts and reqest reqMgr to select a specific
  -- memory device and finally start the "buffMgr" state machine.

  mbxSM : PROCESS (clk, rst_n)
   BEGIN
     IF rst_n = '0' THEN
       mbxState <= waitForIrq;
       startBuffmgr <= '0';
       checkValidFlag <= '0';
       memSel_i <= '0';
       startMemSelect <= '0';
       sdoType_i <= (OTHERS => '0');
     ELSIF clk'event AND clk = '1' THEN
       
       CASE mbxState IS

         WHEN waitForIrq =>
           checkValidFlag <= '0';
           IF startCheckValidFlag = '1' THEN
             -- reqMgr has already selected flash2
             mbxState <= runBuffMgr;
             startBuffmgr <= '1';
             checkValidFlag <= '1';
           ELSIF mbxIrq = '1' THEN
             -- Need to select memory device
             mbxState <= evaluateIrq;
             sdoType_i <= sdoType;
           ELSE
             mbxState <= waitForIrq;
           END IF;
         
         WHEN evaluateIrq =>
           mbxState <= sendReq;
           IF sdoType_i = "0010" THEN
             -- Select EEPROM
             memSel_i <= '1';
           ELSIF sdoType_i = "0011" THEN
             -- Select EEPROM
             memSel_i <= '1';
           ELSIF sdoType_i = "0100" THEN
             -- Select Flash
             memSel_i <= '0';
           ELSE
             -- Invalid SDO type
             mbxState <= waitForIrq;
           END IF;

         WHEN sendReq =>
           startMemSelect <= '1';
           mbxState <= waitForAck;

         WHEN waitForAck =>
           startMemSelect <= '0';
           IF memSelectDone = '1' THEN
             mbxState <= runBuffMgr;
             startBuffmgr <= '1';
           ELSE
             mbxState <= waitForAck;
           END IF;
         
         WHEN runBuffMgr =>
           startBuffmgr <= '0';
           IF sdoOpCompleted = '1' THEN
             mbxState <= waitForIrq;
           ELSE
             mbxState <= runBuffMgr;
           END IF;
           
         WHEN OTHERS =>
           mbxState <= waitForIrq;

       END CASE;
     END IF;
   END PROCESS mbxSM;

-------------------------------------------------------------------------------
-- Mailbox interface buffer state machine
-------------------------------------------------------------------------------
  -- Purpose: Depending on request, the TX fifo is preloaded either with data
  -- from the Mailbox unit or hardcoded values corresponding to read one byte
  -- at addr 0xFFFFF0, i.e. where the "validFlag" status byte is written by SW.
  --
  -- Furthermore, it also handles read and write requests from the SPI unit.
  -- Read req: fetch data from mailbox unit and store in TX buffer (applic data)
  -- Write req: buffer SPI data (read from a memory) in RX fifo and upon every
  -- second byte issue a word write to the Mailbox unit.
  
  buffMgrSM : PROCESS (clk, rst_n)
   BEGIN
     IF rst_n = '0' THEN
       txBuffer <= (OTHERS => (OTHERS => '0'));
       rxBuffer <= (OTHERS => '0');
       tmpBuffer <= (OTHERS => '0');         
       buffMgrState <= startState;
       buffMgrState_d <= startState;       
       nextBuffMgrState <= startState;
       spiIrq <= '0';
       validFlagCheckDone <= '0';       
       validFlagStatus <= '0';
       checkValidFlag_i <= '0';
       preloadDone <= '0';
       addrIsPadded <= '0';
       index <= "00";
       appData <= (OTHERS => '0');       
       appDataReq_d <= '0';
       rdDataReq <= '0';
       rdAddr_i <= (OTHERS => '0');
       rdAddr <= (OTHERS => '0');
       wrDataReq <= '0';       
       wrAddr_i <= (OTHERS => '0');
       wrAddr <= (OTHERS => '0');       
       wrData <= (OTHERS => '0');       
       sdoOpError <= '0';
       sdoOpErrorCode <= (OTHERS => '0');
     ELSIF clk'event AND clk = '1' THEN
       buffMgrState_d <= buffMgrState;
       appDataReq_d <= appDataReq;
       
       CASE buffMgrState IS
         
         WHEN startState =>
           validFlagStatus <= '0';
           checkValidFlag_i <= '0';
           addrIsPadded <= '0';
           validFlagCheckDone <= '0';
           index <= "00";
           wrDataReq <= '0';
           rdAddr_i <= (OTHERS => '0');
           sdoOpError <= '0';           
           sdoOpErrorCode <= (OTHERS => '0');
           
           IF startBuffmgr = '1' THEN
             buffMgrState <= preloadTX;
           ELSE
             buffMgrState <= startState;
           END IF;

         WHEN preloadTX =>
           -- validFlagBuffer already loaded since it has hard coded values.
           -- Otherwise, two reads from mbx unit is necessary to fill the 4
           -- bytes large TX buffer
           IF preloadDone = '1' THEN
             buffMgrState <= evaluateInstruction;
             preloadDone <= '0';
           ELSE
             IF checkValidFlag = '1' THEN
               checkValidFlag_i <= '1';
               preloadDone <= '1';
             ELSE
               buffMgrState <= rdFromMbxUnit;
               nextBuffMgrState <= preloadTX;
               IF buffMgrState_d = waitForRdValid THEN
                 -- Second read, preload done after next read
                 preloadDone <= '1';
               ELSE
                 -- First read
                 preloadDone <= '0';
               END IF;
             END IF;
           END IF;

         WHEN evaluateInstruction =>
           IF memSel_i = '1' THEN
             IF txBuffer(2) = WR_INSTR OR txBuffer(2) = RD_INSTR
               OR txBuffer(2) = SE_INSTR THEN
               -- txBuffer index 2 (after preload stage) contains the SPI intruction
               -- and when instr=RD/WR/SE for EEPROM, the msb Addr byte is a "pad
               -- byte" is shall thus be omitted and therefore a new word is
               -- requested and its lower byte replaces the pad addr byte.
               addrIsPadded <= '1';
               buffMgrState <= rdFromMbxUnit;
             ELSE
               buffMgrState <= sendSpiIrq;
               addrIsPadded <= '0';
             END IF;
           ELSE
             buffMgrState <= sendSpiIrq;
             addrIsPadded <= '0';
           END IF;

         WHEN sendSpiIrq =>
           spiIrq <= '1';
           buffMgrState <= waitForSpiRdReq;

         WHEN waitForSpiRdReq =>
           spiIrq <= '0';
           IF sdoOpCompleted = '1' THEN
             -- Operation completed
             rdAddr_i <= (OTHERS => '0');
             buffMgrState <= startState;             
           ELSIF spiRdInProgress = '1' THEN
             -- Prepare to write SPI RX data to mbx unit
             buffMgrState <= waitForSpiWrReq;
           ELSE
             -- Prepare to read applic data from mbx unit
             buffMgrState <= waitForSpiRdReq;
             IF checkValidFlag_i = '1' THEN
               appData <= validFlagBuffer(to_integer(UNSIGNED(appDataAddr(2 DOWNTO 0))));
             ELSIF appDataReq = '1' AND appDataReq_d = '0' THEN
               -- Request edge from SPI unit detected
               buffMgrState <= rdFromMbxUnit;
               nextBuffMgrState <= waitForSpiRdReq;
             ELSE
               -- Muxing applic data to SPI unit
               CASE appDataAddr(1 DOWNTO 0) IS
                 WHEN "00" => appData <= txBuffer(0);
                 WHEN "01" => appData <= txBuffer(1);
                 WHEN "10" => appData <= txBuffer(2);
                 WHEN "11" => appData <= txBuffer(3);                 
                 WHEN OTHERS => appData <= (OTHERS => '0');
               END CASE;
             END IF;
           END IF;           

         WHEN rdFromMbxUnit =>
           rdDataReq <= '1';
           rdAddr <= rdAddr_i;
           buffMgrState <= waitForRdValid;

         WHEN waitForRdValid =>
           rdDataReq <= '0';
           IF rdDataValid = '1' THEN
             IF addrIsPadded = '0' THEN
               -- No pad byte is used for flash instructions or EEPROM
               -- instruction except for EEPROM WR/RD/SE
               txBuffer(to_integer(UNSIGNED(index))) <= rdData(7 DOWNTO 0);                    
               txBuffer(to_integer(UNSIGNED(index + 1))) <= rdData(15 DOWNTO 8);
               index <= index + "10";
               buffMgrState <= nextbuffMgrState;
               rdAddr_i <= rdAddr_i + '1';
             ELSE
               -- Special case when addressing the EEPROM where instr=WR/RD/SE.
               -- The EEPROM uses two address bytes but Flash uses three
               -- address bytes and the Mailbox unit always uses three bytes 
               -- addressing. Therfore, the first(out of three) address byte
               -- recieved is omitted and thus the following bytes will 
               -- unfortunately be found as higher byte in current word and 
               -- lower byte in next read byte. A tmpBuffer is used to fix this:
               rdAddr_i <= rdAddr_i + '1';
               IF appDataAddr = X"000" THEN
                 -- SPI unit is not yet running at this stage, so manually change
                 -- pad value for addr to the real (msb) addr byte
                 txBuffer(3) <= rdData(7 DOWNTO 0);                    
                 tmpBuffer <= rdData(15 DOWNTO 8);
                 buffMgrState <= sendSpiIrq;
               ELSE
                 index <= index + "10";
                 buffMgrState <= nextbuffMgrState;
                 txBuffer(to_integer(UNSIGNED(index))) <= tmpBuffer;                    
                 txBuffer(to_integer(UNSIGNED(index + 1))) <= rdData(7 DOWNTO 0);
                 tmpBuffer <= rdData(15 DOWNTO 8);
               END IF;               
             END IF;             
           ELSE
             buffMgrState <= waitForRdValid;
           END IF;
           
         WHEN waitForSpiWrReq =>
           wrDataReq <= '0';           
           IF spiDataUpd = '1' THEN
             -- SPI unit has read a byte
             IF wrDataBusy = '1' THEN
               buffMgrState <= startState;
               sdoOpError <= '1';
               sdoOpErrorCode <= "0001";
             ELSE
               IF checkValidFlag_i = '1' THEN
                 rxBuffer(7 DOWNTO 0) <= spiData;
                 buffMgrState <= sendAckToReqMgr;
               ELSIF spiDataAddr(0) = '0' THEN
                 -- Write lower byte to rx buffer
                 rxBuffer(7 DOWNTO 0) <= spiData;
                 IF spiDataDone = '1' THEN
                   -- The last byte has been read by SPI unit
                   buffMgrState <= wrToMbxUnit;
                   nextbuffMgrState <= startState;
                   rxBuffer(15 DOWNTO 8) <= (OTHERS => '0');
                 END IF;                 
               ELSE
                 -- Write higher byte to rx buffer                 
                 rxBuffer(15 DOWNTO 8) <= spiData;
                 buffMgrState <= wrToMbxUnit;
                 IF spiDataDone = '1' THEN
                   -- The last byte has been read by SPI unit
                   nextbuffMgrState <= startState;
                 ELSE
                   -- More bytes left
                   nextbuffMgrState <= waitForSpiWrReq;
                 END IF;
               END IF;
             END IF;
           ELSE
             buffMgrState <= waitForSpiWrReq;
           END IF;

         WHEN wrToMbxUnit =>
           wrDataReq <= '1';
           wrAddr <= wrAddr_i;           
           wrData <= rxBuffer;
           buffMgrState <= nextbuffMgrState;
           IF nextBuffMgrState = waitForSpiWrReq THEN
             wrAddr_i <= wrAddr_i + 1;
           ELSE
             wrAddr_i <= (OTHERS => '0');
           END IF;

         WHEN sendAckToReqMgr =>
           buffMgrState <= startState;
           validFlagCheckDone <= '1';
           IF rxBuffer(7 DOWNTO 0) = X"BC" THEN
             validFlagStatus <= '1';
           ELSE
             validFlagStatus <= '0';
           END IF;
                   
         WHEN OTHERS =>
           buffMgrState <= startState;
           
       END CASE;
     END IF;
   END PROCESS buffMgrSM;

-------------------------------------------------------------------------------
-- Continuous assignments 
-------------------------------------------------------------------------------
memSel <= memSel_i;
   
-------------------------------------------------------------------------------
-- Error handling - To be used when more error cases are added
-------------------------------------------------------------------------------
--  errorHandling: PROCESS (clk, rst_n)
--  BEGIN
--    IF rst_n = '0' THEN                
--      sdoOpError <= '0';
--      sdoOpErrorCode <= (OTHERS => '0');
--    ELSIF clk'event AND clk = '1' THEN 
--      sdoOpError <= sdoOpError_i2;
--      sdoOpErrorCode <= sdoOpErrorCode_i2;
--    END IF;
--  END PROCESS errorHandling;
   
-------------------------------------------------------------------------------
   
END ARCHITECTURE rtl;

