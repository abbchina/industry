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
-- Title:               ESM entity
-- File name:           duf_sc/ESM.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:            0.01
-- Prepared by:         CNABB/Ye-Ye Zhang
-- Status:              Edited
-- Date:                2009-09-28
-- **************************************************************************************
-- Related files:       duf_sc/SlaveController_top.vhd
--                      duf_sc/comm_dpm_controller.vhd
-- **************************************************************************************
-- Functional description:
-- 
-- Contains the main state machine. The module is activated by pulsing the start signal
-- and the module flags for completion by pulsing the done signal.
-- 
-- **************************************************************************************
-- Revision 0.00 - 090928, SEROP/PRCB Magnus Tysell
-- Copied from ESM.vhd (Revision 0.6).
-- **************************************************************************************
-- Revision 0.01 - 090928, CNABB/Ye-Ye Zhang
-- Revised ESM state machine.
-- * Removed Check_SM_Match state.
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY ESM IS
  PORT (
    reset_n              : IN  STD_LOGIC;
    clk                  : IN  STD_LOGIC;
    -- DPM signals
	 comm_dpm_web         : OUT STD_LOGIC;
    comm_dpm_dinb        : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    comm_dpm_doutb       : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
    comm_dpm_addrb       : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    ctrl_dpm             : OUT STD_LOGIC;
    -- SC internal signals
	 start                : IN  STD_LOGIC;
    done                 : OUT STD_LOGIC;
    alStatus             : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    alControl            : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    startUpDone          : OUT STD_LOGIC;  -- Slavecontroller (pulse) (The reset to ECAT IP can now be released!)    
    -- Memory signals
    reconfig_n           : OUT STD_LOGIC;  -- PUC_TOP
    flashSelectMirror    : IN  STD_LOGIC;  -- PUC_TOP
    flashToSel           : OUT STD_LOGIC;  -- SPI_Unit (level. Flash1= '0', Flash2 = '1')  
    startFlashSelect     : OUT STD_LOGIC;  -- SPI_Unit (pulse) (use also the "flashToSelect")
    flashSelectDone      : IN  STD_LOGIC;  -- SPI_Unit (pulse)    
    startFlashValidCheck : OUT STD_LOGIC;  -- SPI_Unit (pulse) (use also the "flashToSelect")
    flashValidCheckDone  : IN  STD_LOGIC;  -- SPI_Unit (pulse)
    flashValidFlagOk     : IN  STD_LOGIC;  -- SPI_Unit (Level must be zero as soon as a write to flash2 is started!)
    -- ConfigUnit signals
    cfgDone              : IN  STD_LOGIC   -- CFG_unit Level, '1'= application config done.
    );
END ESM;

ARCHITECTURE rtl OF ESM IS

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

  -- ESM state machine states
  CONSTANT INIT_STATE        : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"1";
  CONSTANT BOOTSTRAP_STATE   : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"3";
  CONSTANT PRE_OP_STATE      : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"2";
  CONSTANT SAFE_OP_STATE     : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"4";   
  CONSTANT OP_STATE          : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"8";
  -- AL register address
  CONSTANT AL_STATUS_CODE_ADDR  : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0134";
  CONSTANT AL_STATUS_ADDR       : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0130";
  CONSTANT AL_CONTROL_ADDR      : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0120";
  -- AL control and status signals
  SIGNAL alStatus_i        : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL alControl_i       : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL alStatusState     : STD_LOGIC_VECTOR(3 DOWNTO 0);
  SIGNAL alControlState    : STD_LOGIC_VECTOR(3 DOWNTO 0);
  SIGNAL alStatusCode      : STD_LOGIC_VECTOR(15 DOWNTO 0);
  -- DPM Controller signals
  SIGNAL cdc_ctrl_register : std_logic_VECTOR(15 downto 0); 
  SIGNAL cdc_read_data     : std_logic_VECTOR(15 downto 0);
  SIGNAL cdc_write_data    : std_logic_VECTOR(15 downto 0);
  SIGNAL cdc_addr          : std_logic_VECTOR(15 downto 0);
  SIGNAL cdc_done          : std_logic;
  -- ESM state machine
  TYPE ESM_STATE_TYPE IS (Begin_StartUp, Wait_Valid_Check_Done, Wait_For_Flash_Select_Done, Wait_For_Run_ESM, Read_AL_Control_Reg,
                          Check_Error_Ind, Check_State_Transition, To_Init, Bootstrap_Init, Init_PreOP, Init_BootStrap, PreOP_SafeOP,
                          SafeOP_OP, OP_SafeOP, SafeOP_PreOP, OP_PreOP, Update_AL_Status_Code_register, Update_AL_Status_register);                            
  SIGNAL esm_state : ESM_STATE_TYPE;

BEGIN

-------------------------------------------------------------------------------
-- Handle the ESM state machine process
-------------------------------------------------------------------------------
  ESM_ctrl: PROCESS (reset_n,clk) IS
  BEGIN
    IF reset_n = '0' THEN
      done              <= '0'; 
      ctrl_dpm          <= '0';
      cdc_ctrl_register <= (OTHERS => '0');
      cdc_write_data    <= (OTHERS => '0');
      cdc_addr          <= (OTHERS => '0'); 
      esm_state         <= Begin_StartUp;
      alStatus_i        <= "0000" & INIT_STATE;
      alControl_i       <= "0000" & INIT_STATE;
      alStatus          <= "0000" & INIT_STATE;
      alControl         <= "0000" & INIT_STATE;
      alStatusState     <= INIT_STATE;
      alControlState    <= INIT_STATE;
      alStatusCode      <= X"0000"; -- "No error".
      reconfig_n            <= '1';
      startFlashSelect      <= '0';
      flashToSel            <= '0';  -- Flash1.                     
      startUpDone           <= '0';
      startFlashValidCheck  <= '0';
    ELSIF clk'event AND clk = '1' THEN
      alStatus       <= alStatus_i;
      alStatusState  <= alStatus_i(3 DOWNTO 0);
      alControl      <= alControl_i; 
      alControlState <= alControl_i(3 DOWNTO 0);
      
		CASE esm_state IS
    
        WHEN Begin_StartUp => 
          IF flashSelectMirror = '1' THEN           -- Flash2 selected?
            startupDone <= '1';
            esm_state   <= Wait_For_Run_ESM;        -- The FPGA is configured with the latest available valid FW image (flash2); so starting it up.   
          ELSE 
            startFlashValidCheck <= '1';
            flashToSel  <= '1';
            esm_state   <= Wait_Valid_Check_Done;
          END IF;
   
        WHEN Wait_Valid_Check_Done =>
          startFlashValidCheck <= '0';
          flashToSel <= '0';
          IF flashValidCheckDone = '1' THEN
            IF flashValidFlagOk = '1' THEN          -- The FW image in Flash2 is valid.
              reconfig_n    <= '0';                 -- RECONFIGURE FPGA WITH IMAGE IN FLASH2!       
            ELSE                                    -- The FW image in Flash2 is NOT valid, can not reboot from Flash2!
              startFlashSelect <= '1';              -- Starting to select Flash.
              flashToSel    <= '0';                 -- Flash 1.
              esm_state     <= Wait_For_Flash_Select_Done;
            END IF;     
          END IF;

        WHEN Wait_For_Flash_Select_Done => 
          startFlashSelect <= '0';
          IF flashSelectDone = '1' THEN
            IF flashSelectMirror = '0' THEN
              startUpDone <= '1';               -- The FPGA is configured with the latest available valid FW image (flash1); so starting it up.
              esm_state <= Wait_For_Run_ESM;
            END IF;
          END IF;
                            
        WHEN Wait_For_Run_ESM => 
          IF start = '1' THEN            -- ESM start signal from the slavecontroller.
            esm_state <= Read_AL_Control_Reg;
          ELSE
            done <= '0';
            esm_state <= Wait_For_Run_ESM;
          END IF;
            
        WHEN Read_AL_Control_Reg =>         -- Read AL_CONTROL_REG
          IF cdc_done = '1' THEN
            ctrl_dpm <= '0';
            cdc_ctrl_register(0) <= '0';
            alControl_i <= cdc_read_data(7 DOWNTO 0);           
            esm_state   <= Check_Error_Ind;
          ELSE
            cdc_addr <= AL_CONTROL_ADDR;
            ctrl_dpm <= '1';
            cdc_ctrl_register(0) <= '1';
          END IF;
                    
        WHEN Check_Error_Ind => 
          IF alStatus_i(4) = '1' THEN  
            -- Error_Ind in Al Status is set.
            IF alControl_i(4) = '1' THEN           -- Ack by the master: reset the Error Ind in Al Status.                          
              alStatus_i(4)  <= '0'; 
              esm_state      <= Check_State_Transition;
              alStatusCode   <= X"0000";          -- "No error".
            ELSE
              -- Error_Ind in Al Status is set and there was no ack by the master => Ignore, go to Idle.
              esm_state <= Wait_For_Run_ESM;
              done  <= '1';                -- Signal to slavecontroller; ESM IS DONE!.
            END IF;
          ELSE   
            -- Error_Ind in Al Status is not set.
            alStatusCode   <= X"0000";          -- Reset of alStatusCode. "No error".
            esm_state      <= Check_State_Transition;
          END IF;

        -- Determine state transition:                            
        WHEN Check_State_Transition => 
         -- Check if the requested state is a known state:
          IF (alControlState = INIT_STATE) OR (alControlState = BOOTSTRAP_STATE) OR (alControlState = PRE_OP_STATE) OR 
             (alControlState = SAFE_OP_STATE) OR (alControlState = OP_STATE) THEN                             
            -- Define state transition:
            IF (alStatusState = alControlState) THEN    
              -- Requested state is the same as the current state.
              -- Stay in the current state.
              alStatusCode   <= X"0000";            -- "No error".
              esm_state      <= Update_AL_Status_Code_register;
            ELSIF (alStatusState > alControlState) AND (alControlState = INIT_STATE) AND (alStatusState /= BOOTSTRAP_STATE) THEN        -- From known state to INIT (except from Bootstrap). 
              esm_state <= To_Init;
            ELSIF (alStatusState = INIT_STATE)  AND (alControlState = BOOTSTRAP_STATE) THEN     -- INIT TO BOOTSTRAP
              esm_state <= Init_Bootstrap;
            ELSIF (alStatusState = BOOTSTRAP_STATE) AND (alControlState = INIT_STATE) THEN      -- BOOTSTRAP TO INIT  
              IF flashSelectMirror /= '0' THEN         -- Flash1 selected?
                -- Starting to select Flash1:
                startFlashSelect <= '1';
                flashToSel    <= '0'; 
              END IF;          
              esm_state <= Bootstrap_Init;
            ELSIF (alStatusState = INIT_STATE)  AND (alControlState = PRE_OP_STATE) THEN           -- INIT TO PRE_OP
              esm_state <= Init_PreOP;
            ELSIF (alStatusState = PRE_OP_STATE) AND (alControlState = SAFE_OP_STATE) THEN         -- PRE_OP TO SAFE_OP
              esm_state <= PreOP_SafeOP;
            ELSIF (alStatusState = SAFE_OP_STATE) AND (alControlState = OP_STATE) THEN             -- SAFE_OP TO OP
              esm_state <= SafeOP_OP;                  
            ELSIF   (alStatusState = OP_STATE) AND (alControlState = SAFE_OP_STATE) THEN           -- OP TO SAFE_OP
              esm_state <= OP_SafeOP;
            ELSIF   (alStatusState = SAFE_OP_STATE) AND (alControlState = PRE_OP_STATE) THEN       -- SAFE_OP TO PRE_OP
              esm_state <= SafeOP_PreOP;
            ELSIF   (alStatusState = OP_STATE) AND (alControlState = PRE_OP_STATE) THEN            -- OP TO PRE_OP
              esm_state <= OP_PreOP;  
            ELSE                                                                                                                        
              -- Unknown state transition. Report, AL_Status_Code = 0x0011.   
              alStatusCode <= X"0011";    -- "Unknown requested state change".
              esm_state <= Update_Al_Status_Code_register;
            END IF;
          ELSE
            --Unknown requested state. Report, AL_Status_Code = 0x0012.
            alStatusCode <= X"0012";        -- "Unknown requested state".
            esm_state <= Update_Al_Status_Code_register;
          END IF;
                    
        -- Perform state transition actions:
        WHEN To_Init => 
          alStatus_i(3 downto 0) <= INIT_STATE;               
          alStatusCode <= X"0000";    -- "No error".
          esm_state <= Update_AL_Status_Code_register;
                    
        WHEN Bootstrap_Init =>
          startFlashSelect <= '0';
          IF flashValidCheckDone = '1' THEN
            IF flashSelectMirror = '0' THEN    -- Flash1 selected? 
              reconfig_n <= '0';                       -- STARTING REGONFIGURATION OF THE FPGA!                            
            END IF;
          ELSIF flashSelectMirror = '0' THEN
            reconfig_n <= '0';                     -- STARTING REGONFIGURATION OF THE FPGA!                            
          END IF;

        WHEN Init_PreOP =>
          -- Check mailbox SM and activate the Syncmanager if the syncmanagers for mailbox are correctly configured. -> Confirm state, and set alStatusCode.       
          alStatus_i(3 downto 0) <= PRE_OP_STATE;
          alStatusCode <= X"0000";    -- "No error".
          esm_state <= Update_AL_Status_Code_register;

        WHEN Init_BootStrap =>  
          -- Check mailbox SM and activate the Syncmanager if the syncmanagers for mailbox are correctly configured. -> Confirm state, and set alStatusCode.  
          alStatus_i(3 downto 0) <= BOOTSTRAP_STATE;
          alStatusCode <= X"0000";    -- "No error".
          esm_state <= Update_AL_Status_Code_register;

        WHEN PreOP_SafeOP   =>
          -- Start process data input.
          alStatus_i(3 downto 0) <= SAFE_OP_STATE;
          alStatusCode <= X"0000";    -- "No error".
          esm_state <= Update_AL_Status_Code_register;

        WHEN SafeOP_OP =>
          -- Start process data output.
          alStatus_i(3 downto 0) <= OP_STATE;
          alStatusCode <= X"0000";    -- "No error".
          esm_state <= Update_AL_Status_Code_register;

        WHEN OP_SafeOP =>
          -- Stop process data output.
          alStatus_i(3 downto 0) <= SAFE_OP_STATE;
          alStatusCode <= X"0000";    -- "No error".
          esm_state <= Update_AL_Status_Code_register;

        WHEN SafeOP_PreOP =>
          -- Stop process data input.
          alStatus_i(3 downto 0) <= PRE_OP_STATE;
          alStatusCode <= X"0000";    -- "No error".
          esm_state <= Update_AL_Status_Code_register;
                    
        WHEN OP_PreOP =>
          -- Stop process data input and output.
          alStatus_i(3 downto 0) <= PRE_OP_STATE;             
          alStatusCode <= X"0000";    -- "No error".
          esm_state <= Update_AL_Status_Code_register;
            
        -- Transition done, update AL_Status_reg and AL_Status_Code:        
        WHEN Update_AL_Status_Code_register =>  -- Update the AL_STATUS_CODE_REG with alStatusCode.
          IF cdc_done = '1' THEN
            ctrl_dpm <= '0';
            cdc_ctrl_register(1) <= '0';
            IF alStatusCode /= X"0000" THEN         -- Any error; update the "ERROR_IND" bit in alStatus.
              alStatus_i(4) <= '1';
            ELSE
              alStatus_i(4) <= '0';                           -- Remove this? Possibly will reset the error ind without an ack from master? (Shold not enter this if the error ind flag was already set.)
            END IF;
            esm_state  <= Update_AL_Status_register;
          ELSE
            cdc_write_data <= alStatusCode;
            cdc_addr <= AL_Status_Code_addr;
            ctrl_dpm <= '1';
            cdc_ctrl_register(1) <= '1';
          END IF;

        WHEN Update_AL_Status_register =>               -- Update the AL_STATUS_REG with alStatus_i.
          IF cdc_done = '1' THEN
            ctrl_dpm <= '0';
            cdc_ctrl_register(1) <= '0';
            done <= '1';                        -- Signal to slavecontroller; ESM IS DONE!.
            esm_state  <= Wait_For_Run_ESM;
          ELSE
            cdc_write_data <= X"00" & alStatus_i;
            cdc_addr <= AL_STATUS_ADDR;
            ctrl_dpm <= '1';
            cdc_ctrl_register(1) <= '1';
          END IF;
                
      END CASE;
    END IF;
  END PROCESS ESM_ctrl;

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

