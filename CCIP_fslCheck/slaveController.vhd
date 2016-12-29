-- **************************************************************************************
-- (c) Copyright 2009 ABB
--
-- The information contained in this document has to be kept strictly
-- confidential. Any unauthorised use, reproduction, distribution, 
-- or disclosure to third parties is strictly forbidden. 
-- ABB reserves all rights regarding Intellectual Property Rights
-- **************************************************************************************
-- File information
-- Document number: 		
-- Title:               Slave Controller entity
-- File name:           duf_sc/slaveController.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:            0.02
-- Prepared by:         CNABB/Ye-Ye Zhang
-- Status:              Edited
-- Date:                2009-10-30
-- **************************************************************************************
-- Related files:       duf_sc/SlaveController_top.vhd
--                      duf_sc/comm_dpm_controller.vhd
-- **************************************************************************************
-- Functional description:
-- 
-- This module handles the; initialization of the drive events, validation of process 
-- data output, updating of the supervision and interrupt controller, control of the 
-- cyclical and ESM modules and updating of the Feedback Header and Unit Feedback in the
-- process data input.
-- 
-- **************************************************************************************
-- Revision 0.00 - 090927, SEROP/PRCB Magnus Tysell
-- Copied from slaveController.vhd (Revision 0.23).
-- **************************************************************************************
-- Revision 0.01 - 090928, CNABB/Ye-Ye Zhang
-- Revised Slave Controller state machine.
-- * Removed EtherCAT_Init state.
-- * Replaced Wait_DL_Status state with InitConnect state.
-- * Disabled Sync Manager functions.
-- * Removed SM_CHANGE_EVENT related.
-- * Revised Handle_Event state.
-- * Replaced Run_Mailbox state with Run_SDO state.
-- **************************************************************************************
-- Revision 0.02 - 091030, CNABB/Ye-Ye Zhang
-- Revised SAFE_OP_STATE and OP_STATE conditions.
-- * Currently merged these two states together.
-- * Replaced "= OP_STATE" with ">= SAFE_OP_STATE".
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY slaveController IS
  PORT(
    reset_n              : IN  STD_LOGIC;
    clk                  : IN  STD_LOGIC;
    -- IRQ signals
    eventTrigg           : IN  STD_LOGIC;
    irqLevel             : IN  STD_LOGIC;
    -- DPM signals
    comm_dpm_web         : OUT STD_LOGIC;
    comm_dpm_dinb        : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    comm_dpm_doutb       : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
    comm_dpm_addrb       : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    ctrl_dpm             : OUT STD_LOGIC;
    -- ESM internal signals
    ESM_start            : OUT STD_LOGIC;
    ESM_done             : IN  STD_LOGIC;
    alStatus             : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
    alControl            : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
    startUpDone          : IN  STD_LOGIC;
    -- SDO internal signals
    sdoWriteEvent        : OUT STD_LOGIC;
    sdoReadEvent         : OUT STD_LOGIC;
    SDO_done             : IN  STD_LOGIC;
    -- Cyclical internal signals
    cyclical_start       : OUT STD_LOGIC;
    cyclical_done        : IN  STD_LOGIC;
    validFrame           : OUT STD_LOGIC;
    -- Supervision internal signals
    errorTrigg           : IN  STD_LOGIC;
    commFailure          : IN  STD_LOGIC;
    lostFrames           : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    resetCommFailure     : OUT STD_LOGIC;
    periodicStarted      : OUT STD_LOGIC;
    -- PU internal ports
    activeNodes          : OUT STD_LOGIC_VECTOR(6 DOWNTO 1);
    onlyIgnoreNodes      : OUT STD_LOGIC;
    puTrigg              : OUT STD_LOGIC;
    puErrorTrigg         : OUT STD_LOGIC;
    sampleADCEveryPeriod : OUT STD_LOGIC;
    powerBoardSupplyFail : IN  STD_LOGIC
    );
END slaveController;

ARCHITECTURE rtl OF slaveController IS

  COMPONENT comm_dpm_controller
    PORT (
      reset_n        : IN  STD_LOGIC;
      clk            : IN  STD_LOGIC;
      comm_dpm_web   : OUT STD_LOGIC;
      comm_dpm_dinb  : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      comm_dpm_doutb : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      comm_dpm_addrb : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
      ctrl_register  : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      data_in        : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      data_out       : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      addr           : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
      done           : OUT STD_LOGIC
      );
  END COMPONENT;

-------------------------------------------------------------------------------
-- Signal declarations:
-------------------------------------------------------------------------------

  -- Start Up actions steps:
  -- Temperary disabled DL Status test
  -- CONSTANT DL_Status_addr : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0110";		-- EEPROM "loaded correctly"/"not loaded" 1/0 at bit index 0.
  -- FW/VHDL revision number: (Update this number when creating a new revision of the code!)
  CONSTANT FW_Revision      : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0035";		
  CONSTANT FW_Revision_addr : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"1004";
  -- Only testing: (Shall be replaced with values read from PROM.)
  CONSTANT PU_DSQC          : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0299";  -- X"0299" = DSQC665 (6ax LV). X"0297" = DSQC663 (6ax HV).
  CONSTANT PU_DSQC_addr     : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"1006";
  -- Only testing: (Shall be replaced with values read from PROM.)
  CONSTANT PU_Version       : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0001";
  CONSTANT PU_Version_addr  : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"1008";
  -- Only testing: (Shall be replaced with values read from PROM.)
  CONSTANT PU_Revision      : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0001";
  CONSTANT PU_Revision_addr : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"100A";
  -- Connect Init actions steps:
  -- 1. Reset Interrupt Mask for AlEvent
  -- 2. Set ESM to init state 
  CONSTANT AL_Status_addr      : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0130";
  CONSTANT AL_Status_Code_addr : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0134";
  -- 3. Set Interrupt Mask to map Al Control (0x0001) - and Process Data Output (0x0100) events to system IRQ  
  CONSTANT  nr_Connect_Init_actions  : INTEGER := 4;
  TYPE      Connect_Init_array_type IS ARRAY (0 TO (nr_Connect_Init_actions-1)) OF STD_LOGIC_VECTOR(15 DOWNTO 0);  
  CONSTANT  Connect_Init_addr  : Connect_Init_array_type := (FW_Revision_addr, PU_DSQC_addr, PU_Version_addr, PU_Revision_addr);
  CONSTANT  Connect_Init_data  : Connect_Init_array_type := (FW_Revision, PU_DSQC, PU_Version, PU_Revision);
  -- Handle Event actions steps:
  -- 1. Read AlEvent Request register
  CONSTANT AL_Event_Request_addr             : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0220";
  -- 2. (Check if WD has expired in state OP) 
  -- CONSTANT Watchdog_Status_Process_Data_addr : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0440";
  -- 3. Read AlControl register to acknowledge event and get current state
  CONSTANT AL_Control_addr                   : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0120";
  -- Run ESM actions steps:
  -- Temperary only PreOP and OP were used.
  -- Other ESM states conditions should be added later.
  CONSTANT INIT_STATE       : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"1";
  CONSTANT BOOTSTRAP_STATE  : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"3";
  CONSTANT PRE_OP_STATE     : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"2";
  CONSTANT SAFE_OP_STATE    : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"4";	
  CONSTANT OP_STATE         : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"8";
  -- Setup IntC actions steps:
  CONSTANT  nr_Setup_IntC_actions : INTEGER := 3;
  TYPE      IntC_Array_Type IS ARRAY (0 TO 2) OF STD_LOGIC_VECTOR(15 DOWNTO 0);    
  CONSTANT  Setup_Intc_addr : IntC_Array_Type := (X"0008", X"000D", X"0012");
  -- Set number of actions:
  CONSTANT nr_Handle_Event_actions   : INTEGER := 2;
  CONSTANT nr_Run_ESM_actions        : INTEGER := 4;
  --(MAX of nr_Connect_Init_actions,nr_Handle_Event_actions,nr_Run_ESM_actions,nr_Setup_IntC_actions)
  CONSTANT sc_max_nr_actions  : INTEGER := 4;  
  CONSTANT max_nbr_nodes      : INTEGER := 6;
  SIGNAL actions_counter : INTEGER RANGE 0 TO sc_max_nr_actions;
  CONSTANT Byte_size_int : INTEGER := 255;
  TYPE NodeNbr_buffer_array IS ARRAY(0 TO 5) OF INTEGER RANGE 0 TO 7;
  -- Slave Controller state machine
  TYPE SC_STATE_TYPE IS (WaitForStartupDone, InitConnect, WaitForEvent, Get_Event, Handle_Event, Update_Process_Data_Output, 
                         Read_RefHeader, Check_IsRefData, Check_SeqNr, Correct_Frame_Received, Get_Cmd, Update_IntC, Run_Cyclical, 
                         Run_ESM, Run_SDO, Update_SC_Status, Update_FdbkHeader, Update_Process_Data_Input, error, delay1, delay2, Run_Cyclical_Error);
  SIGNAL sc_state : SC_STATE_TYPE;
  -- Masking for AlEvent Request register 
  CONSTANT AL_CONTROL_EVENT     : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0001";
  -- CONSTANT SM_CHANGE_EVENT      : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0010";
  CONSTANT SDO_WRITE_EVENT      : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0100";
  CONSTANT SDO_READ_EVENT       : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0200";
  CONSTANT PROCESS_OUTPUT_EVENT : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0400";
  -- Process data header and command address in Communication DPM
  CONSTANT RefHeader_addr     : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0005";
  CONSTANT UnitCmd_addr       : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0006";
  CONSTANT FdbkHeader_addr    : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0018";  
  CONSTANT UnitStatus_addr    : std_logic_VECTOR(15 downto 0) := X"0019";  
  -- DPM Controller signals
  SIGNAL cdc_ctrl_register : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL cdc_read_data     : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL cdc_write_data    : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL cdc_addr          : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL cdc_done          : STD_LOGIC;
  -- Frame related signals
  SIGNAL alEvent              : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL NodeNbr              : INTEGER RANGE 0 TO max_nbr_nodes;
  SIGNAL UnitCmd              : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL RefSeq               : INTEGER RANGE 0 TO Byte_size_int;
  SIGNAL RefSeq_last          : INTEGER RANGE 0 TO Byte_size_int;
  SIGNAL FdbkHeader           : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL FdbkSeq              : INTEGER RANGE 0 TO Byte_size_int;
  SIGNAL buffer_index         : INTEGER RANGE 0 TO 5;
  SIGNAL NodeNbr_buffer       : NodeNbr_buffer_array;
  SIGNAL Updated_First_Time   : STD_LOGIC;
  SIGNAL nr_ignore_nodes      : integer range 0 to 3;
  SIGNAL EEPROMLoaded		   : STD_LOGIC;
  SIGNAL isReferenceData      : STD_LOGIC;
  SIGNAL isReferenceDataError : STD_LOGIC;  
  SIGNAL resetCommFailure_i   : STD_LOGIC;
  SIGNAL refSeqError		      : STD_LOGIC;
  SIGNAL refTimeout		      : STD_LOGIC;
  SIGNAL periodicStarted_i    : STD_LOGIC;
  SIGNAL lostFrames_i         : STD_LOGIC_VECTOR(4 DOWNTO 0);
  SIGNAL firstTriggInCommFailureDone : STD_LOGIC;
  SIGNAL driveUnitType        : STD_LOGIC_VECTOR(7 DOWNTO 0); -- Used only for Wireshark.

BEGIN

  resetCommFailure <= resetCommFailure_i;

-------------------------------------------------------------------------------
-- Slave Controller state machine:
-------------------------------------------------------------------------------
  slave_ctrl :
  PROCESS (reset_n, clk) IS
  BEGIN
    IF reset_n = '0' THEN
      ctrl_dpm                    <= '0';
      actions_counter             <= 0;
      alEvent                     <= (OTHERS => '0');
      UnitCmd                     <= (OTHERS => '0');
      NodeNbr                     <= 0;
      ESM_start                   <= '0';
      RefSeq                      <= 0;
      RefSeq_last                 <= 0;
      Updated_First_Time          <= '0';
      FdbkHeader                  <= (OTHERS => '0');
      FdbkSeq                     <= 0;
      NodeNbr_buffer              <= (OTHERS => 0); 
      buffer_index                <= 0;
      cdc_ctrl_register           <= (OTHERS => '0');
      cdc_write_data              <= (OTHERS => '0');
      cdc_addr                    <= (OTHERS => '0');		
      cyclical_start              <= '0'; 
      sc_state                    <= WaitForStartupDone;
      onlyIgnoreNodes             <= '0';
      nr_ignore_nodes             <= 0;
      activeNodes                 <= (OTHERS => '0');
      EEPROMLoaded	             <= '0';
      sdoWriteEvent               <= '0';
      sdoReadEvent                <= '0';
      periodicStarted	          <= '0';
      periodicStarted_i	          <= '0';
      isReferenceData	          <= '0';
      isReferenceDataError        <= '0';	
      resetCommFailure_i          <= '0';
      lostFrames_i                <= (OTHERS => '0');
      lostFrames                  <= (OTHERS => '0');
      refSeqError	                <= '0';
      refTimeout	                <= '0';
      validFrame                  <= '0';		
      puTrigg                     <= '0';
      firstTriggInCommFailureDone <= '0';
      sampleADCEveryPeriod        <= '0';
      driveUnitType               <= (OTHERS => '0');
      puErrorTrigg                <= '0';
    ELSIF clk'event AND clk = '1' THEN           
      lostFrames      <= lostFrames_i;
      periodicStarted <= periodicStarted_i;
      IF (alStatus(3 DOWNTO 0) >= SAFE_OP_STATE) THEN
        IF commFailure = '1' THEN
          periodicStarted_i <= '0';
        ELSE
          periodicStarted_i <= Updated_First_Time;
        END IF;
      ELSE
        periodicStarted_i   <= '0';
      END IF;  
	  
      CASE sc_state IS

        WHEN WaitForStartupDone =>
          IF startUpDone = '1' THEN
            sc_state <= InitConnect;
          END IF;

        WHEN InitConnect =>
          --Send init signal to CPU through FSL bus
          IF cdc_done = '1' THEN
            --A comm DPM access is finished
            --Releases control of comm DPM
            ctrl_dpm             <= '0';
            cdc_ctrl_register(1) <= '0';
          END IF;
          IF cdc_ctrl_register(1) = '0' THEN
            IF actions_counter < nr_Connect_Init_actions THEN
              --All actions in this state are performed
              cdc_addr <= Connect_Init_addr(actions_counter);
              cdc_write_data <= Connect_Init_data(actions_counter);
              --Takes control of comm DPM (by muxing the comm DPM input signals)
              ctrl_dpm <= '1';
              --Start a write ECS register access
              cdc_ctrl_register(1) <=	'1';
              actions_counter <= actions_counter + 1;
              sc_state <= InitConnect;
            ELSE
              actions_counter <= 0;
              sc_state <= WaitForEvent;
            END IF;
          ELSE
            sc_state <= InitConnect;
          END IF; 
	
        WHEN WaitForEvent =>
          --Does nothing until an event trigg arrives (mapped to irq_level)
--          IF irqLevel = '1' THEN
--            sc_state <= Get_Event;
          --ELSIF
          IF (errorTrigg = '1') AND (alStatus(3 downto 0) >= SAFE_OP_STATE) THEN  
            -- Supervision signals a missed frame
            IF commFailure = '1' THEN
              -- Only one puErrorTrigg pulse shall be generated when 
              -- being in communication failure:
              IF firstTriggInCommFailureDone = '1' THEN
                puErrorTrigg     <= '0';
                sc_state         <= WaitForEvent;
              ELSE                
                puErrorTrigg <= '1';
                firstTriggInCommFailureDone <= '1';
                sc_state     <= error;
              END IF;
            ELSE
              -- Generate puErrorTrigg when there is a missing frame but no communication failure.
              puErrorTrigg  <= '1';
              firstTriggInCommFailureDone <= '0';
              sc_state      <= error;
            END IF;
            refTimeout	<= '1';
            activeNodes <= (OTHERS => '0');
          ELSE
            -- Clear error bits in SC status register;
            puErrorTrigg <= '0';
            refSeqError  <= '0';
            refTimeout	 <= '0';
            isReferenceDataError <= '0';
            activeNodes  <= (OTHERS => '0');
            sc_state     <= Get_Event; -- WaitForEvent;
          END IF;
					
        WHEN Get_Event =>
          --Reads the Al Event Request register, which defines what event caused the irq
          IF cdc_done = '1' THEN
            ctrl_dpm <= '0'; 
            cdc_ctrl_register(0) <= '0';
            alEvent  <= cdc_read_data;
            sc_state <= Handle_Event;
          ELSE
            cdc_addr <= AL_Event_Request_addr;
            ctrl_dpm <= '1';
            --Start a read ECS register access
            cdc_ctrl_register(0) <=	'1';
            sc_state <= Get_Event;
          END IF;
													
        WHEN Handle_Event =>
          --Analyzes the event and starts the corresponding process
          IF (alEvent AND AL_CONTROL_EVENT) = AL_CONTROL_EVENT THEN
            -- State change request
				-- Disabled SM_CHANGE_EVENT
            -- alEvent <= alEvent AND NOT(SM_CHANGE_EVENT);
            sc_state <= Run_ESM;
            ESM_start <= '1';
          ELSIF ((alEvent AND PROCESS_OUTPUT_EVENT) = PROCESS_OUTPUT_EVENT) AND (alStatus(3 downto 0) >= SAFE_OP_STATE) THEN  		
            --New process data has arrived
            sc_state <= Update_Process_Data_Output;  			
          ELSIF ((alEvent AND SDO_WRITE_EVENT) = SDO_WRITE_EVENT) AND (alStatus(3 downto 0) >= PRE_OP_STATE)  THEN 						
            sdoWriteEvent <= '1';
            sc_state <= Run_SDO;	
          ELSIF ((alEvent AND SDO_READ_EVENT) = SDO_READ_EVENT) AND (alStatus(3 downto 0) >= PRE_OP_STATE)  THEN 						
            sdoReadEvent <= '1';
            sc_state <= Run_SDO;								
          ELSE 
            --unknown event goto WaitForEvent
            actions_counter <= 0;
            sc_state <= WaitForEvent;	
          END IF;
			
        -- Step into ESM state machine
        WHEN Run_ESM =>
          ESM_start <= '0';
          IF ESM_done = '1' THEN
            sc_state	<= WaitForEvent;
          END IF;
				
        -- Step into SDO state machine
        WHEN Run_SDO =>
          sdoWriteEvent <= '0';
          sdoReadEvent <= '0';					
          IF SDO_done = '1' THEN
            sc_state	<= WaitForEvent;
          END IF;

        -- Step into process data input/output
        WHEN Update_Process_Data_Output =>
          -- Commands the comm interface to read process data from ECS to DPM
          IF cdc_done = '1' THEN
            ctrl_dpm <= '0';
            cdc_ctrl_register(2) <=	'0';				
            sc_state <= Read_RefHeader;
          ELSE
            ctrl_dpm <= '1';
            cdc_ctrl_register(2) <=	'1';
            sc_state <= Update_Process_Data_Output;
          END IF;

        WHEN Read_RefHeader =>
          --Reads the RefHeader data word from the Slave
          IF cdc_done = '1' THEN
            ctrl_dpm  <= '0';
            cdc_ctrl_register(4)  <= '0';
            driveUnitType   <= cdc_read_data(7 DOWNTO 0);
            RefSeq   		<= conv_integer(cdc_read_data(11 DOWNTO 8));
            isReferenceData	<= cdc_read_data(15);
            sc_state 		<= Check_IsRefData;
          ELSE
            cdc_addr <= RefHeader_addr;
            ctrl_dpm <= '1';
            cdc_ctrl_register(4) <= '1';
            sc_state <= Read_RefHeader;
          END IF;
            
        WHEN Check_IsRefData => 
          IF isReferenceData = '1' THEN
            isReferenceDataError <= '0';
            sc_state <= Get_Cmd;
          ELSE
            -- Not reference data, error!  
            isReferenceDataError <= '1';
            puTrigg   <= '1';
            sc_state  <= Error;
          END IF;
          
        WHEN Get_Cmd =>
          --Reads UnitCmd from process data area and checks for cmd requests
          IF cdc_done = '1' THEN
            ctrl_dpm <= '0';
            cdc_ctrl_register(4) <= '0';
            UnitCmd 			  <= cdc_read_data;
            resetCommFailure_i 	  <= cdc_read_data(0); 
            sampleADCEveryPeriod  <= cdc_read_data(2); 
            activeNodes <= (others => '0');
            sc_state  <= Check_SeqNr;
          ELSE
            cdc_addr <= UnitCmd_addr;
            ctrl_dpm <= '1';
            cdc_ctrl_register(4) <= '1';
            sc_state <= Get_Cmd;
          END IF ;
					
        WHEN Check_SeqNr =>             			
          --Checks the sequence number of the incoming frame
          --Updates the next frames expected sequence number and feedback sequence number with the current sequence number 
          IF RefSeq = (RefSeq_last + 1) OR (RefSeq_last = 15 AND RefSeq = 0) THEN
            --Seq no. have increased by 1 since last frame
            FdbkSeq     <= RefSeq;      --correct sequence number
            RefSeq_last <= RefSeq;
            refSeqError	<= '0';
            sc_state    <= Correct_Frame_Received;
          ELSE
            --Sequence number have not increased by 1 since last frame
            IF (Updated_First_Time = '0') OR  (resetCommFailure_i = '1') THEN
              --store the first sequence number
              FdbkSeq     <= RefSeq;
              RefSeq_last <= RefSeq;
              refSeqError <= '0';
              sc_state    <= Correct_Frame_Received;
            ELSE
              refSeqError <= '1';
              puTrigg     <= '1';
              sc_state    <= error;
            END IF;
          END IF;

        WHEN Correct_Frame_Received =>
          --Reset number of consecutive frame errors in status register and report to supervision
          lostFrames_i <= (OTHERS => '0');
          FdbkHeader(11 DOWNTO 8) <= conv_std_logic_vector(FdbkSeq,4);	-- New robocat, 4 bits sequence number.
          validFrame  <= '1';
          Updated_First_Time <= '1';
          firstTriggInCommFailureDone <= '0';
          puTrigg     <= '1';       -- Correct frame received, generate the puTrigg (pulse)!
          sc_state    <= Update_IntC;	
		  
        WHEN Update_IntC =>
          puTrigg     <= '0';
          IF cdc_done = '1' THEN -- so its only done once (done asserted for two cycles)
            cdc_ctrl_register(4) <= '0';
            ctrl_dpm <= '0';
            NodeNbr <= (conv_integer(cdc_read_data(2 downto 0)));
            --Buffers the active nodes in case of erroneous frames
            NodeNbr_buffer(buffer_index + 3) <= NodeNbr_buffer(buffer_index);
            NodeNbr_buffer(buffer_index)  <= (conv_integer(cdc_read_data(2 downto 0))); -- <= NodeNbr;
            buffer_index <= buffer_index + 1;
            actions_counter <= actions_counter + 1;
          END IF;
						
          IF cdc_ctrl_register(4) = '0' THEN
            --Read&update node number
              IF NodeNbr = 0 THEN
                nr_ignore_nodes <= nr_ignore_nodes + 1;
              ELSE
                IF actions_counter /= 0 THEN   -- Do not set activenodes the first time you enter here. First read the first inverterReference data.
                  activeNodes(NodeNbr) <= '1';
                END IF;
              END IF;
            IF actions_counter < nr_Setup_IntC_actions THEN 
              cdc_addr <= Setup_Intc_addr(actions_counter);
              ctrl_dpm <= '1';
              cdc_ctrl_register(4) <= '1';
              sc_state <= Update_IntC;
            ELSE
              IF nr_ignore_nodes = 3 THEN  -- Maty 080326 Checking if all nodes are "ignore nodes". 
                onlyIgnoreNodes    <= '1';  
              END IF;              
              nr_ignore_nodes <= 0;
              buffer_index    <= 0;
              actions_counter <= 0;
              cyclical_start  <= '1';
              sc_state <= Run_Cyclical;
            END IF;
          ELSE
            sc_state   <= Update_IntC;
          END IF;

        -- Step into Cyclical state machine
        WHEN Run_Cyclical =>
          --Runs the application
          cyclical_start <= '0';        -- (Only one clock cycle long pulse).
          IF cyclical_done = '1' THEN  --maybe should not wait for it to be finished  --change                                            
            sc_state     <= Update_SC_Status;
          ELSE
            sc_state     <= Run_Cyclical;
          END IF;

        WHEN Update_SC_Status =>
          -- Updates Unit status:
          onlyIgnoreNodes <= '0';  
          IF cdc_done = '1' THEN
            ctrl_dpm <= '0';
            cdc_ctrl_register(5) <= '0';
            sc_state <= Update_FdbkHeader;
          ELSE
		    cdc_write_data <= X"00" & "00" & powerBoardSupplyFail & resetCommFailure_i & refTimeout & refSeqError & isReferenceDataError & commFailure;
            cdc_addr <= UnitStatus_addr;
            ctrl_dpm <= '1';
            cdc_ctrl_register(5) <= '1';
            sc_state <= Update_SC_Status;
          end if;

        WHEN Update_FdbkHeader =>
          --Updates FdbkHeader data word with the feedback sequence number
          IF cdc_done = '1' THEN
            ctrl_dpm <= '0';
            cdc_ctrl_register(5) <= '0';
            sc_state <= Update_Process_Data_Input;
          ELSE
            cdc_write_data <= '0' & "000" & FdbkHeader(11 DOWNTO 8) & driveUnitType;	-- bit15: isReferenceData = 0 = feedback data. driveUnitType for use in wireshark.
            cdc_addr <= FdbkHeader_addr;
            ctrl_dpm <= '1';
            cdc_ctrl_register(5) <= '1';
            sc_state <= Update_FdbkHeader;
          END IF;

        WHEN Update_Process_Data_Input =>
          -- Commands the comm interface to read process data from comm DPM to ECS DPM
          IF cdc_done = '1' THEN
            ctrl_dpm <= '0';
            cdc_ctrl_register(3) <= '0';
            sc_state <= WaitForEvent;
          ELSE
            ctrl_dpm <= '1';
            cdc_ctrl_register(3) <= '1';
            sc_state <= Update_Process_Data_Input;
          END IF;

        WHEN error =>
          --Update RefReceiveError in SC status register
          puTrigg       <= '0';
          puErrorTrigg  <= '0';
          validFrame    <= '0';
          IF periodicStarted_i = '1' THEN
            --Increase error counter in status register and report to supervision 
            IF commFailure = '0' THEN  
              -- Update the lostFrames counter if no communication failure.
              lostFrames_i <= lostFrames_i + X"1";
            END IF;
            --Increase "fake" sequence number using the last valid
            IF FdbkSeq = 15 THEN  -- New robocat 4 bits sequesnce number => value = 15 instead of "Byte_Size_Int".
  			      FdbkSeq     <= 0;
              RefSeq_last <= 0;
            ELSE
              FdbkSeq     <= FdbkSeq + 1;
              RefSeq_last <= FdbkSeq + 1;
            END IF;
            -- MaTy: 071011 Added: Else, the feadback header is not updated with the FdbkSeq:
  		    FdbkHeader(11 DOWNTO 8) <= conv_std_logic_vector(FdbkSeq, 4);  
            --Update intC control register with old node numbers
            IF NodeNbr_buffer(3) /= 0 THEN
              activeNodes(NodeNbr_buffer(3)) <= '1';
            END IF;
            IF NodeNbr_buffer(4) /= 0 THEN
              activeNodes(NodeNbr_buffer(4)) <= '1';
            END IF;
            IF NodeNbr_buffer(5) /= 0 THEN
              activeNodes(NodeNbr_buffer(5)) <= '1';
            END IF;
            --Swap buffer data
            NodeNbr_buffer(0) <= NodeNbr_buffer(3);
            NodeNbr_buffer(1) <= NodeNbr_buffer(4);
            NodeNbr_buffer(2) <= NodeNbr_buffer(5);
            NodeNbr_buffer(3) <= NodeNbr_buffer(0);
            NodeNbr_buffer(4) <= NodeNbr_buffer(1);
            NodeNbr_buffer(5) <= NodeNbr_buffer(2);
            --Delays by two cycles so that supervision has time to update comm_failure 
  	      --in case this frame will cause this.
            sc_state <= delay1;
          ELSE
            -- Periodic commmunication not started, abort!
            sc_state <= WaitForEvent;
          END IF;

        WHEN delay1 =>
          --Delays by one cycle
          sc_state <= delay2;

        WHEN delay2 =>
          --Delays by one cycle
          sc_state <= Run_Cyclical_Error;

        WHEN Run_Cyclical_Error =>
          --Starts cyclical if comm_failure is deasserted
          cyclical_start  <= '1';
          sc_state <= Run_Cyclical;
          
      END CASE;
    END IF;
  END PROCESS slave_ctrl;

-------------------------------------------------------------------------------
-- Component instatiations: 
-------------------------------------------------------------------------------	

  comm_dpm_controller_inst : comm_dpm_controller
    PORT MAP(
      reset_n        => reset_n,
      clk            => clk,
      comm_dpm_web   => comm_dpm_web,
      comm_dpm_dinb  => comm_dpm_dinb,
      comm_dpm_doutb => comm_dpm_doutb,
      comm_dpm_addrb => comm_dpm_addrb,
      ctrl_register  => cdc_ctrl_register,
      data_in        => cdc_write_data,
      data_out       => cdc_read_data,
      addr           => cdc_addr,
      done           => cdc_done
      );

END rtl;

