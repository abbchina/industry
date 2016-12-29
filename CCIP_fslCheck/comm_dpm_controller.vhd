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
--	Title:					comm_dpm_controller
--	File name:				../comm_dpm_controller.vhd
-- **************************************************************************************
-- Revision information
-- Revision index: 		0
-- Revision:				0.1
-- Prepared by:		   SECRC/MRA Erik Nilsson
-- Status:					Edited
-- Date:						2009-04-21
-- **************************************************************************************
-- Related files:
-- **************************************************************************************
-- Functional description:
-- 
-- Interface between the ECS application and the communication dpm. 
-- It is operated by the ECS application through a simple handshaking protocol;
-- The control register (ctrl_register) and done signals implements the 
-- control protocol (handshaking) while the data_in, data_out and addr signals transfer data.
-- A positive edge on a bit in the ctrl_register starts an access to the ECS DPM through the
-- communication DPM. 
-- The data on the addr and data_in (for write access only) busses must be valid at this time.
-- The accesses end with the assertion of the done signal. The data on the data_out buss is 
-- valid while done is asserted.
-- **************************************************************************************
-- 0.01: 090421 - SEROP/PRCB Magnus Tysell
-- * Read Status register - ctrl_register(6) removed.
-- * Config_Reg_Addr removed.
-- Signal names changed: (cmd:s also changed vector length from 16 bits to 4 bits)
-- * Read_Reg_Cmd   -> READ_ECS_REG_CMD
-- * Write_Reg_Cmd  -> WRITE_ECS_REG_CMD                        
-- * Read_Process_Data_Cmd -> READ_ECS_PROCESS_DATA_CMD
-- * Write_Process_Data_Cmd -> WRITE_ECS_PROCESS_DATA_CMD               
-- * Ctrl_Reg_Addr -> CTRL_REG_ADDR 
-- * Data_Reg_Addr -> DATA_REG_ADDR
-- * Addr_Reg_Addr -> ADDR_REG_ADDR
-- * internal_ctrl_register -> ctrl_register_d;
-- * delay_time changed from integer to integer range 0 to 
-- * comm_status -> ctrlRegData
-- **************************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY comm_dpm_controller IS
  PORT (
    reset_n        : IN  STD_LOGIC;
    clk            : IN  STD_LOGIC;
    comm_dpm_web   : OUT STD_LOGIC;
    comm_dpm_dinb  : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
    comm_dpm_doutb : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
    comm_dpm_addrb : OUT STD_LOGIC_VECTOR (5 DOWNTO 0);
    ctrl_register  : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
    data_in        : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
    data_out       : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    addr           : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
    done           : OUT STD_LOGIC
    );
END comm_dpm_controller;

ARCHITECTURE Behavioral OF comm_dpm_controller IS

  -- COMM_DPM addresses used for communication with communication_top through the comm_dpm.
  CONSTANT CTRL_REG_ADDR : STD_LOGIC_VECTOR(5 DOWNTO 0) := B"000000";
  CONSTANT DATA_REG_ADDR : STD_LOGIC_VECTOR(5 DOWNTO 0) := B"000011";
  CONSTANT ADDR_REG_ADDR : STD_LOGIC_VECTOR(5 DOWNTO 0) := B"000100";

  -- Commands used for communication with communication_top through the comm_dpm.
  CONSTANT READ_ECS_REG_CMD           : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"1";
  CONSTANT WRITE_ECS_REG_CMD          : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"2";
  CONSTANT READ_ECS_PROCESS_DATA_CMD  : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"4";
  CONSTANT WRITE_ECS_PROCESS_DATA_CMD : STD_LOGIC_VECTOR(3 DOWNTO 0) := X"8";

  TYPE STATE_TYPE IS (Idle, Write_CMD_To_commDPM, Read_Ctrl_Register, Read_Reg_Command_Finish,
                      Write_Register_Data, Write_Register_Addr, Write_Register_Ctrl, Write_Reg_Command_Finish,
                      Output_Read_Data, Read_Process_Data, Read_Process_Data_Command_Finish, Write_Process_Data,
                      Write_Process_Data_Command_Finish, Delay1, Delay2, Delay3, Delay4, Delay5);
  SIGNAL cdc_state : STATE_TYPE;

  SIGNAL ctrlRegData     : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL ctrl_register_d : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL delay_time      : INTEGER RANGE 0 TO 3;


BEGIN

  cdc_ctrl : PROCESS (reset_n, clk) IS
  BEGIN
    IF reset_n = '0' THEN
      comm_dpm_dinb        <= (OTHERS => '0');
      comm_dpm_addrb       <= (OTHERS => '0');
      comm_dpm_web         <= '0';
      done                 <= '0';
      data_out             <= (OTHERS => '0');
      ctrlRegData          <= (OTHERS => '0');
      delay_time           <= 0;
      ctrl_register_d      <= (OTHERS => '0');
      cdc_state            <= Idle;
    ELSIF clk'event AND clk = '1' THEN
      ctrl_register_d      <= ctrl_register;
      CASE cdc_state IS
        WHEN Idle =>
          --Do nothing until a read or write request
          done             <= '0';
          comm_dpm_web     <= '0';
          ctrlRegData      <= X"0000";
          IF ctrl_register(0) = '1' AND ctrl_register_d(0) = '0' THEN  --edge triggered
            --Read register in Ethercat slave
            comm_dpm_web   <= '1';
            comm_dpm_addrb <= ADDR_REG_ADDR;
            comm_dpm_dinb  <= addr;
            cdc_state      <= Write_CMD_To_commDPM;
          ELSIF ctrl_register(1) = '1' AND ctrl_register_d(1) = '0' THEN
            --Write register in Ethercat slave
            comm_dpm_web   <= '1';
            comm_dpm_addrb <= ADDR_REG_ADDR;
            comm_dpm_dinb  <= addr;
            cdc_state      <= Write_Register_Addr;
          ELSIF ctrl_register(2) = '1' AND ctrl_register_d(2) = '0' THEN
            --Read process data from EtherCat slave (ref data)
            comm_dpm_web   <= '1';
            comm_dpm_addrb <= CTRL_REG_ADDR;
            comm_dpm_dinb  <= X"000" & READ_ECS_PROCESS_DATA_CMD;
            cdc_state      <= Read_Process_Data;
          ELSIF ctrl_register(3) = '1' AND ctrl_register_d(3) = '0' THEN
            --Write process data to Ethercat slave (fbk data)
            comm_dpm_web   <= '1';
            comm_dpm_addrb <= CTRL_REG_ADDR;
            comm_dpm_dinb  <= X"000" & WRITE_ECS_PROCESS_DATA_CMD;
            cdc_state      <= Write_Process_Data;
          ELSIF ctrl_register(4) = '1' AND ctrl_register_d(4) = '0' THEN
            --Read process data word from comm_dpm (ref data)
            comm_dpm_addrb <= addr(5 DOWNTO 0);
            --Takes a few (three) cycles before the comm_dpm_doutb contains valid data
            delay_time     <= 2;
            cdc_state      <= Delay2;
          ELSIF ctrl_register(5) = '1' AND ctrl_register_d(5) = '0' THEN
            --Write process data word to comm_dpm (fbk data)
            comm_dpm_web   <= '1';
            comm_dpm_addrb <= addr(5 DOWNTO 0);
            comm_dpm_dinb  <= data_in;
            done           <= '1';
            cdc_state      <= idle;
          ELSE
            cdc_state      <= Idle;
          END IF;

        WHEN Write_CMD_To_commDPM =>
          -- Writes the requested command to the control reg in the comm_DPM
          comm_dpm_web   <= '1';
          comm_dpm_addrb <= CTRL_REG_ADDR;
          comm_dpm_dinb  <= X"000" & READ_ECS_REG_CMD;
          cdc_state      <= Read_Ctrl_Register;

        WHEN Read_Ctrl_Register =>
          -- Start the read access to contol reg in comm_DPM, to check if the comm_top has completed
          -- the requested command in (see state Read_Reg_Command_Finish).
          comm_dpm_web   <= '0';
          comm_dpm_addrb <= CTRL_REG_ADDR;
          --Takes a few (four) cycles before the comm_dpm_doutb contains valid data
          --one more because it was preceeded by a write operation (DPM properties).
          delay_time     <= 3;
          cdc_state      <= Delay1;

        WHEN Delay1 =>
          --Delays the process by delay_time + 1 cycles to wait for valid data.
          IF delay_time = 0 THEN
            ctrlRegData <= comm_dpm_doutb;
            cdc_state   <= Read_Reg_Command_Finish;
          ELSE
            delay_time  <= delay_time - 1;
            cdc_state   <= Delay1;
          END IF;

        WHEN Read_Reg_Command_Finish =>
          --Waits until the Read_Reg bit in the CTRL_REG_ADDR is deasserted
          IF ctrlRegData(0) = '0' THEN  -- READ_ECS_REG_CMD reset by communication_top.
            --Command executed
            comm_dpm_addrb <= DATA_REG_ADDR;
            --Takes a few (three) cycles before the comm_dpm_doutb contains valid data
            delay_time     <= 2;
            cdc_state      <= Delay2;
          ELSE
            comm_dpm_addrb <= CTRL_REG_ADDR;
            ctrlRegData    <= comm_dpm_doutb;
            cdc_state      <= Read_Reg_Command_Finish;
          END IF;

        WHEN Write_Register_Addr =>
          --Writes the write address to the ADDR_REG_ADDR in the comm DPM 
          comm_dpm_web   <= '1';
          comm_dpm_addrb <= DATA_REG_ADDR;
          comm_dpm_dinb  <= data_in;
          cdc_state      <= Write_Register_Data;

        WHEN Write_Register_Data =>
          --Writes the write data to the Data_Reg_Addr in the comm DPM 
          comm_dpm_web   <= '1';
          comm_dpm_addrb <= CTRL_REG_ADDR;
          comm_dpm_dinb  <= X"000" & WRITE_ECS_REG_CMD;
          cdc_state <= Write_Register_Ctrl;

        WHEN Write_Register_Ctrl =>
          --Asserts the Write_Reg bit in the CTRL_REG_ADDR in the comm DPM
          comm_dpm_web   <= '0';
          comm_dpm_addrb <= CTRL_REG_ADDR;
          --Takes a few (four) cycles before the comm_dpm_doutb contains valid data
          --one more because it was preceeded by a write operation (DPM properties).
          delay_time     <= 3;
          cdc_state      <= Delay5;

        WHEN Delay5 =>
          --Delays the process by delay_time + 1 cycles 
          IF delay_time = 0 THEN
            ctrlRegData <= comm_dpm_doutb;
            cdc_state   <= Write_Reg_Command_Finish;
          ELSE
            delay_time  <= delay_time - 1;
            cdc_state   <= Delay5;
          END IF;

        WHEN Write_Reg_Command_Finish =>
          --Waits until the Write_Reg bit in the CTRL_REG_ADDR is deasserted
          IF ctrlRegData(1) = '0' THEN  -- WRITE_ECS_REG_CMD reset by communication_top.
            --Command executed
            done           <= '1';
            cdc_state      <= Idle;
          ELSE
            comm_dpm_addrb <= CTRL_REG_ADDR;
            ctrlRegData    <= comm_dpm_doutb;
            cdc_state      <= Write_Reg_Command_Finish;
          END IF;

        WHEN Delay2 =>
          --Delays the process by delay_time + 1 cycles
          IF delay_time = 0 THEN
            cdc_state  <= Output_Read_Data;
          ELSE
            delay_time <= delay_time - 1;
            cdc_state  <= Delay2;
          END IF;

        WHEN Output_Read_Data =>
          -- Signals that the command is finished and data_out is valid.
          -- The data_out is either comm_dpm data or ECS data, depending on CMD.
          done      <= '1';
          data_out  <= comm_dpm_doutb;
          cdc_state <= Idle;

        WHEN Read_Process_Data =>
          --Asserts the Read_Process_Data bit in the CTRL_REG_ADDR in the comm DPM 
          comm_dpm_web   <= '0';
          comm_dpm_addrb <= CTRL_REG_ADDR;
          --Takes a few (four) cycles before the comm_dpm_doutb contains valid data
          --one more because it was preceeded by a write operation (DPM properties).
          delay_time     <= 3;
          cdc_state      <= Delay3;

        WHEN Delay3 =>
          --Delays the process by delay_time + 1 cycles
          IF delay_time = 0 THEN
            ctrlRegData <= comm_dpm_doutb;
            cdc_state   <= Read_Process_Data_Command_Finish;
          ELSE
            delay_time <= delay_time - 1;
            cdc_state  <= Delay3;
          END IF;

        WHEN Read_Process_Data_Command_Finish =>
          --Waits until the Read_Process_Data bit in the CTRL_REG_ADDR is deasserted                            
          IF ctrlRegData(2) = '0' THEN  -- READ_ECS_PROCESS_DATA_CMD reset by communication_top.
            --Command executed
            done           <= '1';
            cdc_state      <= Idle;
          ELSE
            comm_dpm_addrb <= CTRL_REG_ADDR;
            ctrlRegData    <= comm_dpm_doutb;
            cdc_state      <= Read_Process_Data_Command_Finish;
          END IF;

        WHEN Write_Process_Data =>
          --Asserts the Write_Process_Data bit in the CTRL_REG_ADDR in the comm DPM
          comm_dpm_web   <= '0';
          comm_dpm_addrb <= CTRL_REG_ADDR;
          --Takes a few (four) cycles before the comm_dpm_doutb contains valid data
          delay_time     <= 3;
          cdc_state      <= Delay4;

        WHEN Delay4 =>
          --Delays the process by delay_time + 1 cycles
          IF delay_time = 0 THEN
            ctrlRegData <= comm_dpm_doutb;
            cdc_state   <= Write_Process_Data_Command_Finish;
          ELSE
            delay_time  <= delay_time - 1;
            cdc_state   <= Delay4;
          END IF;

        WHEN Write_Process_Data_Command_Finish =>
          --Waits until the Write_Process_Data bit in the CTRL_REG_ADDR is deasserted   
          IF ctrlRegData(3) = '0' THEN  -- WRITE_ECS_PROCESS_DATA_CMD reset by communication_top.
            --Command executed
            done           <= '1';
            cdc_state      <= Idle;
          ELSE
            comm_dpm_addrb <= CTRL_REG_ADDR;
            ctrlRegData    <= comm_dpm_doutb;
            cdc_state      <= Write_Process_Data_Command_Finish;
          END IF;

      END CASE;
    END IF;
  END PROCESS cdc_ctrl;

END Behavioral;

