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
-- Title:               Serial Peripheral Interface (SPI)
-- File name:           spi_rtl_a.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:		0.1
-- Prepared by:		SEROP/PRCB Björn Nyqvist
-- Status:		First version
-- Date:		2008-10-16
-- **************************************************************************************
-- References:
-- 1. Datasheet ST M95512-R 512Kbit Serial SPI EEPROM
-- 2. Datasheet Numonyx M25P80 8Mbit Serial SPI Flash
-- 3. IS - SPI unit in R19/R21 3HAC TBD
-- **************************************************************************************
-- Functional description:
--
-- Application data means data from the application to be transmitted to the memories.
-- Spi data means data received from the memories.
--
-- The application data must consist of two header bytes and then instruction
-- and address and data if any:
--
-- byte0 = Header. Revision bit7-bit4
-- byte0 = Header. Size bit3-bit0
-- byte1 = Header. Size (Concatinated to byte0) 
-- byte2 = SPI instruction
-- byte3 = data
-- byte(n) = data
--
-- Upon an spiIrq, this component starts to read application data and shifts
-- out data on the SPI interface. Unless the number of shifted out bytes are
-- equal as "size" specified in the header, the SPI unit request application
-- unit to provide new applic data by means of appDataReq.
--
-- When a spi data byte is completely read the spiDataUpd is set in order to
-- notify the master application to fetch the byte.
--
-- memSel: 0 = flash / 1 = eeprom, used for addressing correctly since flash
-- uses three address bytes and eeprom 2 address bytes
--
-- spiClkFreqDiv is a generic utilized to specify SPI clock frequency.
--
-- **************************************************************************************
-- changes:
-- 1.1 
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.numeric_std.ALL;

ENTITY spi IS
  GENERIC (
    spiClkFreqDiv   :     NATURAL := 25
    );
  PORT(
    rst_n           : IN  STD_LOGIC;
    clk             : IN  STD_LOGIC;
    -- Application interface
    spiIrq          : IN  STD_LOGIC;
    memSel          : IN  STD_LOGIC;
    spiOpCompleted  : OUT STD_LOGIC;
    -- TX data, i.e. transmitted to SPI
    appData         : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
    appDataAddr     : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    appDataReq      : OUT STD_LOGIC;
    -- RX data, i.e. received from SPI
    spiData         : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    spiDataAddr     : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    spiDataUpd      : OUT STD_LOGIC;
    spiDataDone     : OUT STD_LOGIC;
    spiRdInProgress : OUT STD_LOGIC;
    -- SPI PHY interface
    miso            : IN  STD_LOGIC;
    mosi            : OUT STD_LOGIC;
    spiCs_n         : OUT STD_LOGIC;
    spiClk          : OUT STD_LOGIC
    );
END spi;

ARCHITECTURE rtl OF spi IS

  CONSTANT NO_OF_BYTES_LIMIT : INTEGER := 4096;

  -- Instructions, see ref 1 and 2 for furhter details:
  CONSTANT WREN : STD_LOGIC_VECTOR(7 DOWNTO 0) := B"0000_0110";
  CONSTANT WRDI : STD_LOGIC_VECTOR(7 DOWNTO 0) := B"0000_0100";
  CONSTANT RDSR : STD_LOGIC_VECTOR(7 DOWNTO 0) := B"0000_0101";
  CONSTANT WRSR : STD_LOGIC_VECTOR(7 DOWNTO 0) := B"0000_0001";
  CONSTANT RD   : STD_LOGIC_VECTOR(7 DOWNTO 0) := B"0000_0011";
  CONSTANT WR   : STD_LOGIC_VECTOR(7 DOWNTO 0) := B"0000_0010";
  CONSTANT BE   : STD_LOGIC_VECTOR(7 DOWNTO 0) := B"1100_0111";  

  -- Related to SPI application process
  TYPE APP_STATE_TYPE IS (waitForIrq, getByte, setRevision, setNoOfBytes, checkInstruction, runOp);
  SIGNAL appState             : APP_STATE_TYPE;
  SIGNAL nextAppState         : APP_STATE_TYPE;
  SIGNAL currentByte          : STD_LOGIC_VECTOR(7 DOWNTO 0);  
  SIGNAL appDataAddr_i        : STD_LOGIC_VECTOR(11 DOWNTO 0);  
  SIGNAL rdOffset             : NATURAL RANGE 0 TO 4;
  SIGNAL noOfBytes            : NATURAL RANGE 0 TO (NO_OF_BYTES_LIMIT - 1);
  SIGNAL revNo                : STD_LOGIC_VECTOR(3 DOWNTO 0);  
  SIGNAL sizeMsb              : STD_LOGIC_VECTOR(3 DOWNTO 0);
  SIGNAL size                 : STD_LOGIC_VECTOR(11 DOWNTO 0);    
  SIGNAL rwn                  : STD_LOGIC;
  SIGNAL rdInProgess          : STD_LOGIC;  
  SIGNAL startOp              : STD_LOGIC;
  SIGNAL appDataReq_i         : STD_LOGIC;
  
  -- Related to SPI physical process
  TYPE PHY_STATE_TYPE IS (waitForStartOp, setClkHigh, setClkLow, setCsLow, setCsHigh, delayOnePeriod);
  SIGNAL phyState             : PHY_STATE_TYPE;
  SIGNAL phyState_d           : PHY_STATE_TYPE;
  SIGNAL nextPhyState         : PHY_STATE_TYPE;
  SIGNAL getNewByte           : STD_LOGIC;    
  SIGNAL opDone               : STD_LOGIC;
  SIGNAL spiPhyInProgress     : STD_LOGIC;  
  SIGNAL shiftOutCnt          : NATURAL RANGE 0 TO 7;
  SIGNAL shiftInCnt           : NATURAL RANGE 0 TO 8;  
  SIGNAL byteCnt              : NATURAL RANGE 0 TO (NO_OF_BYTES_LIMIT - 1);  
    
  -- Related to "shift process" - outgoing data to a memory
  SIGNAL shiftOutReg          : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL updShiftOutReg       : STD_LOGIC;
  SIGNAL spiDataAddr_i        : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL spiDataAddr_d        : STD_LOGIC_VECTOR(11 DOWNTO 0);      
  
  -- Related to "shift process" - incoming data from a memory
  SIGNAL validMiso            : STD_LOGIC;
  SIGNAL noOfBytesTransmitted : NATURAL RANGE 0 TO (NO_OF_BYTES_LIMIT - 1);
  SIGNAL misoMetaReg          : STD_LOGIC_VECTOR(2 DOWNTO 0);  
  SIGNAL shiftInReg           : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL shiftInCnt_d          : NATURAL RANGE 0 TO 8;
  
  -- For generation of the spi clk enable pulse
  SIGNAL spiClkEn             : STD_LOGIC;
  SIGNAL clkCnt               : NATURAL RANGE 1 TO spiClkFreqDiv;
  ATTRIBUTE SIGIS             : STRING;
  ATTRIBUTE SIGIS of spiClkEn : SIGNAL IS "CLK";


BEGIN
  
-------------------------------------------------------------------------------
-- spi clock enable generation
-------------------------------------------------------------------------------
  -- Purpose: Creating the SPI clock enable out of the generic spiClkFreqDiv.
  -- An example: if the input clock clk = 100Mhz and spiClkFreqDiv = 25,
  -- the period of spiClkEn is 250 ns and at each pulse the spiClk is chaning
  -- state which yields a periof of spiClk = 500 ns = 2 Mhz.
   gen2Mhz : PROCESS (clk, rst_n)
   BEGIN 
     IF rst_n = '0' THEN
       clkCnt <= 1;
       spiClkEn <= '0';
     ELSIF clk'event AND clk = '1' THEN
       IF clkCnt = spiClkFreqDiv THEN
         clkCnt <= 1;
         spiClkEn <= '1';
       ELSE
         clkCnt <= clkCnt + 1;
         spiClkEn <= '0';
       END IF;
     END IF;
   END PROCESS gen2Mhz;
   
-------------------------------------------------------------------------------
-- Application layer 
-------------------------------------------------------------------------------
   -- Purpose: Handle incoming data to be sent to the slaves.
   -- Upon a spiIrq, this SM starts to process data until the operation is
   -- completed. Each bulk of process data bytes must be ordered as:
   -- byte0 = state the revision/"msb size" to be processed (header)
   -- byte1 = "size" i.e. the number of bytes to be processed (header)
   -- byte2 = spi instruction
   -- byte3 = data
   -- byte(n) = data
   spiApplic : PROCESS (clk, rst_n)
   BEGIN
     IF rst_n = '0' THEN
       appState <= waitForIrq;
       nextAppState <= waitForIrq;
       appDataAddr_i <= (OTHERS => '0');       
       rdOffset <= 0;
       rwn <= '0';
       noOfBytes <= 0;
       startOp <= '0';
       currentByte <= (OTHERS => '0');
       updShiftOutReg <= '0';
       rdInProgess <= '0';
       noOfBytesTransmitted <= 0;
       sizeMsb <= (OTHERS => '0');
       size <= (OTHERS => '0');
       revNo <= (OTHERS => '0');
     ELSIF clk'event AND clk = '1' THEN
       updShiftOutReg <= '0';
       noOfBytes <= to_integer(UNSIGNED(size));

       IF noOfBytesTransmitted = rdOffset THEN
         rdInProgess <= rwn;
       ELSIF appState = waitForIrq THEN
         rdInProgess <= '0';
       ELSE
         rdInProgess <= rdInProgess;
       END IF;

       CASE appState IS
         
         WHEN waitForIrq =>
           -- An interrupt indicates that application data are ready to be processed
           appDataAddr_i <= (OTHERS => '0');
           IF spiIrq = '1' THEN
             appState <= getByte;               
             nextAppState <= setRevision;
           ELSE
             appState <= waitForIrq;               
           END IF;

         WHEN getByte =>
           IF rdInProgess = '1' THEN
             -- Do not get new data
             appState <= nextAppState;
           ELSE
             -- Fetch next byte in the application data area
             currentByte <= appData;
             appState <= nextAppState;
             appDataAddr_i <= appDataAddr_i + '1';
           END IF;
           
           IF (nextAppState = checkInstruction OR nextAppState = runOp) THEN           
             -- Current byte is a cmd, addr or data
             updShiftOutReg <= '1';
           ELSE
             -- Not update shiftOutReg when current byte is a header byte
             updShiftOutReg <= '0';
           END IF;

         WHEN setRevision =>
           -- Set actual revision and the 4 msb bits of "size"
           appState <= getByte;
           nextAppState <= setNoOfBytes;
           revNo <= currentByte(7 DOWNTO 4);
           sizeMsb <= currentByte(3 DOWNTO 0);

         WHEN setNoOfBytes =>
           -- Set actual size, i.e. how many bytes that is handled in coming operation
           appState <= getByte;
           nextAppState <= checkInstruction;
           size <= sizeMsb & currentByte(7 DOWNTO 0);

         WHEN checkInstruction =>
           -- Check requested operation
           appState <= runOp;
           
           CASE currentByte IS
             
             WHEN RDSR =>
               rwn <= '1';
               -- 1 byte cmd, rdOffset states how many bytes that shall be
               -- processed before valid read data are available on "miso"
               rdOffset <= 1;

             WHEN WREN | WRDI | WRSR | WR =>
               rwn <= '0';
               rdOffset <= 1;

             WHEN RD =>
               rwn <= '1';
               IF memSel = '0' THEN
                 -- 3 bytes addressing (Flash) + 1 byte cmd
                 rdOffset <= 4;
               ELSIF memSel = '1' THEN
                 -- 2 bytes addressing (EEPROM) + 1 byte cmd
                 rdOffset <= 3;
               ELSE
                 rdOffset <= 0;
               END IF;

             WHEN OTHERS =>
               rwn <= rwn;
               rdOffset <= rdOffset;
               
           END CASE;

         WHEN runOp =>
           IF opDone = '1' THEN
             appState <= waitForIrq;
             noOfBytesTransmitted <= 0;
           ELSIF getNewByte = '1' THEN
             noOfBytesTransmitted <= noOfBytesTransmitted + 1;
             appState <= getByte;
             nextAppState <= runOp;
           ELSIF spiPhyInProgress = '1' THEN
             appState <= runOp;
             startOp <= '0';
           ELSE
             appState <= runOp;
             startOp <= '1';           
           END IF;
           
         WHEN OTHERS =>
           appState <= waitForIrq;

       END CASE;
     END IF;
   END PROCESS spiApplic;

   -- Purpose: Control signals for requesting a new applic data. Request send
   -- to master application to load its TX buffer which is read (appData) later
   -- on.
   appInterface : PROCESS (clk, rst_n)
   BEGIN
     IF rst_n = '0' THEN
       appDataReq_i <= '0';
     ELSIF clk'event AND clk = '1' THEN
       appDataReq_i <= '0';       
       IF spiPhyInProgress = '1' THEN
         IF noOfBytesTransmitted < (noOfBytes - 1) THEN
           -- All bytes are not sent out
           IF appDataAddr_i(1 DOWNTO 0) = "11"  THEN
             -- Generate the first request and then every second.
             appDataReq_i <= NOT rdInProgess;             
           ELSIF appDataAddr_i(1 DOWNTO 0) = "01" AND rwn = '0' THEN
             appDataReq_i <= NOT rdInProgess;             
           ELSE
             appDataReq_i <= '0';
           END IF;
         ELSE
           appDataReq_i <= '0';
         END IF;
       END IF;
     END IF;
   END PROCESS appInterface;
   
-------------------------------------------------------------------------------
-- spi physical layer
-------------------------------------------------------------------------------
   -- Purpose: this process implements the SPI physical protocol as well as
   -- generating control signals in order to kepp track of how many bytes that
   -- are left to process, how many bits in each byte are shifter in/out etc.
   spiPhysical : PROCESS (clk, rst_n)
   BEGIN
     IF rst_n = '0' THEN
       opDone  <= '0';
       mosi    <= '0';
       spiCs_n <= '1';
       spiClk  <= '1';
       shiftOutCnt <= 0;
       shiftInCnt <= 0;
       byteCnt <= 0;
       getNewByte <= '0';
       spiPhyInProgress <= '0';
       phyState <= waitForStartOp;
       phyState_d <= waitForStartOp;
       nextPhyState <= waitForStartOp;
     ELSIF clk'event AND clk = '1' THEN
       phyState_d <= phyState;
       getNewByte <= '0';
       opDone <= '0';
       
       IF spiClkEn = '1' THEN
         
         CASE phyState IS
           
           WHEN waitForStartOp =>
             mosi <= '0';
             spiPhyInProgress <= '0';
             opDone <= '0';
             IF startOp = '1' THEN
               phyState <= setCsLow;
               spiPhyInProgress <= '1';
               byteCnt <= noOfBytes;
             END IF;
             
           WHEN setClkHigh =>
             -- Also keep track of how many bits of a byte that is handled
             -- and how many bytes in total that shall be processed.
             spiClk <= '1';
             IF rdInProgess = '0' THEN
               -- Instruction/address/data are written to a memory
               IF shiftOutCnt = 7 THEN
                 -- Current byte is completed
                 shiftOutCnt <= 0;
                 IF byteCnt = 0 THEN
                   -- No data left to shift out -> exit
                   phyState <= delayOnePeriod;
                   nextPhyState <= setCsHigh;
                 ELSE
                   -- There are still bytes left
                   getNewByte <= '1';                   
                   byteCnt <= byteCnt - 1;
                   phyState <= setClkLow;
                 END IF;
               ELSE
                 -- We are in the middle of a byte
                 phyState <= setClkLow;
                 shiftOutCnt <= shiftOutCnt + 1;
               END IF;
             ELSE
               -- Data are read from a memory
               IF shiftInCnt = 8 THEN
                 -- Current byte is completed.
                 -- Note that an extra clk cycle is added during first read in order
                 -- for the FPGA to latch in data on falling edge of spiClk
                 IF byteCnt = 0 THEN
                   -- No data left to shift in -> exit
                   phyState <= delayOnePeriod;
                   nextPhyState <= setCsHigh;
                   shiftInCnt <= 0;                                    
                 ELSE
                   -- There are still bytes left
                   getNewByte <= '1';                                      
                   byteCnt <= byteCnt - 1;
                   phyState <= setClkLow;
                   shiftInCnt <= 1;
                 END IF;                 
               ELSE
                 -- We are in the middle of a byte
                 phyState <= setClkLow;
                 shiftInCnt <= shiftInCnt + 1;
               END IF;
             END IF;
             
           WHEN setClkLow =>
             spiClk <= '0';
             mosi <= shiftOutReg(7);
             phyState <= setClkHigh;
             
           WHEN setCsHigh =>
             spiCs_n <= '1';
             opDone <= '1';
             spiPhyInProgress <= '0';
             phyState <= waitForStartOp;
             
           WHEN setCsLow =>
             spiCs_n <= '0';
             phyState <= delayOnePeriod;
             nextPhyState <= setClkLow;
             
           WHEN delayOnePeriod =>
             phyState <= nextPhyState;
             
           WHEN OTHERS =>
             
         END CASE;
       END IF;       
     END IF;
   END PROCESS spiPhysical;

-------------------------------------------------------------------------------
-- prepare data to be shifted in/out
-------------------------------------------------------------------------------
   --Purpose: Incoming data from the memory are protected towards
   --metastability. Further, data are shifted in/out to/from registers and upon
   --each received byte "spiDataUpd" is set to indicate that valid data are
   --ready to be fetched by master application.
   shift: PROCESS (clk, rst_n)
   BEGIN
     IF rst_n = '0' THEN
       shiftInReg <= (OTHERS => '0');
       shiftOutReg <= (OTHERS => '0');
       spiData <= (OTHERS => '0');
       spiDataAddr_i <= (OTHERS => '0');
       spiDataAddr_d <= (OTHERS => '0');              
       spiDataUpd <= '0';
       spiDataDone <= '0';       
       validMiso <= '0';
       misoMetaReg <= (OTHERS => '0');
       shiftInCnt_d <= 0;
     ELSIF clk'event AND clk = '1' THEN
       spiDataUpd <= '0';
       spiDataDone <= '0';
       shiftInCnt_d <= shiftInCnt;
       spiDataAddr_d <= spiDataAddr_i;
       
       -- To aviod metastability
       misoMetaReg(0) <= miso;
       misoMetaReg(2 DOWNTO 1) <= misoMetaReg(1 DOWNTO 0);
       
       -- Shift out data "mosi" to the slave(s)
       IF updShiftOutReg = '1' THEN
         -- Load the reg with a new data byte       
         shiftOutReg <= currentByte;
       ELSIF phyState = setClkLow AND phyState_d = setClkHigh THEN
         -- Prepare the shiftReg on rising edge since data is clocked out on
         -- falling edge of spi clk
         shiftOutReg(7 DOWNTO 1) <= shiftOutReg(6 DOWNTO 0);
       END IF;
       
       -- Generate the "validMiso" ctrl signal used to determine when valid
       -- input data are valid on "miso".
       IF rdInProgess = '1' AND phyState = setClkHigh THEN
         validMiso <= '1';
       ELSIF phyState = delayOnePeriod THEN
         validMiso <= '0';
       ELSE
         validMiso <= validMiso;
       END IF;
     
       IF validMiso = '1' THEN
         -- Valid data on "miso" to be read
         IF phyState = setClkHigh AND phyState_d = setClkLow THEN
           -- Shift in data from the slave on falling edge         
           shiftInReg(0) <= misoMetaReg(2);
           shiftInReg (7 DOWNTO 1) <= shiftInReg(6 DOWNTO 0);
         ELSIF (shiftInCnt = 0 OR shiftInCnt = 1) AND shiftInCnt_d = 8 THEN
           -- A complete byte is shifted in
           spiData <= shiftInReg;
           spiDataAddr_i <= spiDataAddr_i + '1';
           spiDataUpd <= '1';
           IF noOfBytesTransmitted = noOfBytes THEN
             spiDataDone <= '1';
             spiDataAddr_i <= (OTHERS => '0');
           ELSE
             spiDataDone <= '0';
           END IF;
         END IF;
       END IF;
     END IF;
   END PROCESS shift;
   
-------------------------------------------------------------------------------
-- Continuous assignments 
-------------------------------------------------------------------------------
appDataAddr <= appDataAddr_i;
appDataReq <= appDataReq_i;
spiDataAddr <= spiDataAddr_d;
spiOpCompleted <= opDone;
spiRdInProgress <= rdInProgess;
   
END ARCHITECTURE rtl;

