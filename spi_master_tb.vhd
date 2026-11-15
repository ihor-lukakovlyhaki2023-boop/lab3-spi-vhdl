library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_master_tb is
end spi_master_tb;

architecture Behavioral of spi_master_tb is
    component spi_master
        Generic (
            CLK_DIV : integer := 4
        );
        Port (
            clk     : in  STD_LOGIC;
            reset   : in  STD_LOGIC;
            start   : in  STD_LOGIC;
            tx_data : in  STD_LOGIC_VECTOR (7 downto 0);
            rx_data : out STD_LOGIC_VECTOR (7 downto 0);
            busy    : out STD_LOGIC;
            done    : out STD_LOGIC;
            sclk    : out STD_LOGIC;
            mosi    : out STD_LOGIC;
            miso    : in  STD_LOGIC;
            ss_n    : out STD_LOGIC
        );
    end component;

    signal clk     : STD_LOGIC := '0';
    signal reset   : STD_LOGIC := '0';
    signal start   : STD_LOGIC := '0';
    signal tx_data : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
    signal rx_data : STD_LOGIC_VECTOR (7 downto 0);
    signal busy    : STD_LOGIC;
    signal done    : STD_LOGIC;
    signal sclk    : STD_LOGIC;
    signal mosi    : STD_LOGIC;
    signal miso    : STD_LOGIC := '0';
    signal ss_n    : STD_LOGIC;

    -- Тестовий байт, який нібито відправляє Slave у відповідь (0x3C = 00111100)
    signal slave_tx_data : STD_LOGIC_VECTOR (7 downto 0) := x"3C";
    signal slave_bit_idx : integer range 0 to 7 := 7;

    constant CLK_PERIOD : time := 10 ns; -- Тактова частота 100 МГц
begin

    -- Підключення модуля SPI Master
    uut: spi_master
        generic map (CLK_DIV => 4)
        port map (
            clk     => clk,
            reset   => reset,
            start   => start,
            tx_data => tx_data,
            rx_data => rx_data,
            busy    => busy,
            done    => done,
            sclk    => sclk,
            mosi    => mosi,
            miso    => miso,
            ss_n    => ss_n
        );

    -- Генерація тактового сигналу CLK (100 МГц)
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Імітація поведінки ведомого пристрою (Slave) на лінії MISO
    slave_sim : process(sclk, ss_n)
    begin
        if ss_n = '1' then
            slave_bit_idx <= 7;
            miso <= slave_tx_data(7);
        elsif falling_edge(sclk) then
            if slave_bit_idx > 0 then
                slave_bit_idx <= slave_bit_idx - 1;
                miso <= slave_tx_data(slave_bit_idx - 1);
            end if;
        end if;
    end process;

    -- Основний сценарій тестування
    stim_proc : process
    begin
        -- 1. Скидання системи
        reset <= '1';
        wait for 40 ns;
        reset <= '0';
        wait for 40 ns;

        -- 2. Передача першого байта 0xA5 (10100101)
        tx_data <= x"A5";
        start   <= '1';
        wait for CLK_PERIOD;
        start   <= '0';

        -- Чекаємо завершення транзакції
        wait until done = '1';
        wait for 100 ns;

        -- 3. Друга транзакція: передача 0x5A, відповідь Slave 0xF1
        slave_tx_data <= x"F1";
        tx_data       <= x"5A";
        start         <= '1';
        wait for CLK_PERIOD;
        start         <= '0';

        wait until done = '1';
        wait for 100 ns;

        -- Зупинка симуляції
        assert false report "Simulation Finished Successfully!" severity failure;
        wait;
    end process;

end Behavioral;