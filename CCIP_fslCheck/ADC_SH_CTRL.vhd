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
-- Title:               ADC sample & hold control unit 
-- File name:           ADC_SH_CTRL.vhd
-- **************************************************************************************
-- Revision information
-- Revision index:      0
-- Revision:            0.2
-- Prepared by:         Yang Gao
-- Status:            Edited
-- Date:                2008-06-29
-- **************************************************************************************
-- Related files:
-- **************************************************************************************
-- Functional description:
-- 
-- This block handles the selection of which ADC channel that shall be
-- addressed. Upon a detection of an event on the "trig" signal, this block
-- invokes a read from the ADC
-- **************************************************************************************
-- changes:
-- 0.2: 080629 - SEROP/PRCB Björn Nyqvist
-- * Channel 0 is now over sampled (*2) and a median value is then calculated.
-- **************************************************************************************           
-- 0.3: 081210 - SEROP/PRCB Magnus Tysell
-- * Oversampling of ch0 removed.
-- **************************************************************************************  
-- 0.4: 090202 - SEROP/PRCB Magnus Tysell
-- * Write operations to PU_dpm removed. Added signal vectors for each ADC-channel instead. 
-- **************************************************************************************  



LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;

ENTITY SH_ctrl IS

  PORT(
    clk         : IN  STD_LOGIC;
    rst_n       : IN  STD_LOGIC;
    sync_trig   : IN  STD_LOGIC;
    spi_uin     : IN  STD_LOGIC;
    spi_uout    : OUT STD_LOGIC;
    spi_clk     : OUT STD_LOGIC;
    spi_cs_n    : OUT STD_LOGIC;
    spi_vin     : IN  STD_LOGIC;
    spi_vout    : OUT STD_LOGIC;
    data_out_u0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    data_out_u1 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    data_out_v0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    data_out_v1 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
    );

  ATTRIBUTE SIGIS          : STRING;
  ATTRIBUTE SIGIS OF clk   : SIGNAL   IS "CLK";
  ATTRIBUTE SIGIS OF rst_n : SIGNAL IS "RST";

END SH_ctrl;

ARCHITECTURE rtl OF SH_ctrl IS

  TYPE state_type IS (wait_for_sync, ch0, ch0_done, ch1, ch1_done);

  SIGNAL state                : state_type;
  SIGNAL adcCh                : STD_LOGIC;
  SIGNAL start_conversion     : STD_LOGIC;
  SIGNAL conversion_ready     : STD_LOGIC;
  SIGNAL conversion_ready_d   : STD_LOGIC;
  SIGNAL conversion_ready_pos : STD_LOGIC;
  SIGNAL conv_data_uout       : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL conv_data_vout       : STD_LOGIC_VECTOR(11 DOWNTO 0);
  SIGNAL clk_spi_en           : STD_LOGIC;
  SIGNAL clk_en_counter       : STD_LOGIC_VECTOR(2 DOWNTO 0);
  SIGNAL sync_trig_en         : STD_LOGIC;
  SIGNAL sync_trig_d          : STD_LOGIC;

  COMPONENT spi_if
    PORT (
      clk              : IN  STD_LOGIC;
      clk_en           : IN  STD_LOGIC;
      rst_n            : IN  STD_LOGIC;
      conversion       : IN  STD_LOGIC;
      spi_uin          : IN  STD_LOGIC;
      spi_uout         : OUT STD_LOGIC;
      spi_clk          : OUT STD_LOGIC;
      spi_cs_n         : OUT STD_LOGIC;
      spi_vin          : IN  STD_LOGIC;
      spi_vout         : OUT STD_LOGIC;
      conversion_ready : OUT STD_LOGIC;
      data_in          : IN  STD_LOGIC;
      data_out_u       : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      data_out_v       : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
      );
  END COMPONENT;

BEGIN

  -- generate pulse on positive flank of conversion_ready
  delay_conversion_ready :
  PROCESS(clk, rst_n)
  BEGIN
    IF rst_n = '0' THEN
      conversion_ready_d <= '0';
    ELSIF rising_edge(clk) THEN
      conversion_ready_d <= conversion_ready;
    END IF;
  END PROCESS delay_conversion_ready;
  conversion_ready_pos   <= '1' WHEN conversion_ready = '1' AND conversion_ready_d = '0' ELSE '0';


  Rising_edge_synch_pulse :
  PROCESS(Clk, rst_n)
  BEGIN
    IF (rst_n = '0') THEN
      sync_trig_d <= '0';
    ELSIF (Clk'event AND Clk = '1') THEN
      sync_trig_d <= sync_trig;
    END IF;
  END PROCESS Rising_edge_synch_pulse;
  sync_trig_en    <= '1' WHEN sync_trig = '1' AND sync_trig_d = '0' ELSE '0';


  sampling_sequence_control :
  PROCESS(clk, rst_n)
  BEGIN
    IF (rst_n = '0') THEN
      state            <= wait_for_sync;
      start_conversion <= '0';
      data_out_u0      <= (OTHERS => '0');
      data_out_v0      <= (OTHERS => '0');
      data_out_u1      <= (OTHERS => '0');
      data_out_v1      <= (OTHERS => '0');
      adcCh            <= '0';
    ELSIF rising_edge(clk) THEN
      CASE state IS

        WHEN wait_for_sync =>
          IF sync_trig_en = '1' THEN
            start_conversion <= '1';
            state            <= ch0;
          END IF;

        WHEN ch0 =>
          adcCh         <= '1';
          IF conversion_ready_pos = '1' THEN
            data_out_u0 <= conv_data_uout;
            data_out_v0 <= conv_data_vout;
            state       <= ch0_done;
          END IF;

        WHEN ch0_done =>
          state <= ch1;

        WHEN ch1 =>
          adcCh         <= '0';
          IF conversion_ready_pos = '1' THEN
            data_out_u1 <= conv_data_uout;
            data_out_v1 <= conv_data_vout;
            state       <= ch1_done;
          END IF;

        WHEN ch1_done =>
          start_conversion <= '0';
          state            <= wait_for_sync;

      END CASE;
    END IF;
  END PROCESS sampling_sequence_control;

  ------------------------------------------------------------
  -- ADC clk pace generation
  ------------------------------------------------------------
  -- Generates a clock pace for the ADC. 
  -- The 3bit counter "clk_en_counter" is used to generate a 
  -- ADC clock transition each 8th 100MHz tick. This implies a 
  -- 6,25MHz ADC clock (160ns period time).
  ------------------------------------------------------------
  clk_enable_gen :
  PROCESS(clk, rst_n)
  BEGIN
    IF rst_n = '0' THEN
      clk_spi_en     <= '0';
      clk_en_counter <= (OTHERS => '0');
    ELSIF rising_edge(clk) THEN
      clk_en_counter <= clk_en_counter + 1;
      IF clk_en_counter = "111" THEN
        clk_spi_en   <= '1';
      ELSE
        clk_spi_en   <= '0';
      END IF;
    END IF;
  END PROCESS clk_enable_gen;


  one_axis_spi : spi_if PORT MAP (
    clk              => clk,
    clk_en           => clk_spi_en,
    rst_n            => rst_n,
    conversion       => start_conversion,
    spi_uin          => spi_uin,
    spi_uout         => spi_uout,
    spi_clk          => spi_clk,
    spi_cs_n         => spi_cs_n,
    spi_vin          => spi_vin,
    spi_vout         => spi_vout,
    conversion_ready => conversion_ready,
    data_in          => adcCh,
    data_out_u       => conv_data_uout,
    data_out_v       => conv_data_vout
    );

END ARCHITECTURE rtl;
