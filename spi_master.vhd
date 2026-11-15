library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Модуль SPI Master (Режим Mode 0: CPOL = 0, CPHA = 0, 8 біт, MSB first)
entity spi_master is
    Generic (
        CLK_DIV : integer := 4  -- Дільник тактової частоти (SCLK = CLK / (2 * CLK_DIV))
    );
    Port (
        clk       : in  STD_LOGIC;                     -- Системний тактовий сигнал
        reset     : in  STD_LOGIC;                     -- Синхронне скидання (активний '1')
        start     : in  STD_LOGIC;                     -- Імпульс запуску транзакції
        tx_data   : in  STD_LOGIC_VECTOR (7 downto 0); -- Байт даних для передачі (Tx)
        rx_data   : out STD_LOGIC_VECTOR (7 downto 0); -- Прийнятий байт даних (Rx)
        busy      : out STD_LOGIC;                     -- Прапорець зайнятості модуля
        done      : out STD_LOGIC;                     -- Імпульс завершення передачі
        -- Фізичні інтерфейсні лінії SPI
        sclk      : out STD_LOGIC;                     -- Тактовий сигнал шини SPI
        mosi      : out STD_LOGIC;                     -- Вихід даних Master -> Slave
        miso      : in  STD_LOGIC;                     -- Вхід даних Slave -> Master
        ss_n      : out STD_LOGIC                      -- Вибір ведомого пристрою (активний '0')
    );
end spi_master;

architecture Behavioral of spi_master is
    -- Стани скінченного автомата (FSM)
    type state_type is (IDLE, LOAD_DATA, TRANSFER, DONE_STATE);
    signal state : state_type := IDLE;

    -- Внутрішні регістри та лічильники
    signal tx_shift  : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
    signal rx_shift  : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
    signal bit_cnt   : integer range 0 to 7 := 7;
    signal clk_cnt   : integer range 0 to CLK_DIV := 0;
    signal sclk_reg  : STD_LOGIC := '0';
    signal sclk_prev : STD_LOGIC := '0';
begin

    -- Виведення внутрішніх сигналів на порти
    sclk <= sclk_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state     <= IDLE;
                tx_shift  <= (others => '0');
                rx_shift  <= (others => '0');
                rx_data   <= (others => '0');
                bit_cnt   <= 7;
                clk_cnt   <= 0;
                sclk_reg  <= '0';
                sclk_prev <= '0';
                mosi      <= '0';
                ss_n      <= '1';
                busy      <= '0';
                done      <= '0';
            else
                -- За замовчуванням імпульс done триває 1 такт
                done      <= '0';
                sclk_prev <= sclk_reg;

                case state is
                    -- 1. Очікування команди запуску
                    when IDLE =>
                        ss_n     <= '1';
                        sclk_reg <= '0';
                        busy     <= '0';
                        clk_cnt  <= 0;
                        if start = '1' then
                            state <= LOAD_DATA;
                        end if;

                    -- 2. Завантаження байта у зсувний регістр та активація лінії SS
                    when LOAD_DATA =>
                        tx_shift <= tx_data;
                        rx_shift <= (others => '0');
                        bit_cnt  <= 7;
                        ss_n     <= '0';          -- Опускаємо Chip Select в '0'
                        busy     <= '1';
                        mosi     <= tx_data(7);   -- Виставляємо старший біт (MSB) заздалегідь (CPHA=0)
                        state    <= TRANSFER;

                    -- 3. Генерація тактів SCLK та побітовий обмін даними
                    when TRANSFER =>
                        if clk_cnt < CLK_DIV - 1 then
                            clk_cnt <= clk_cnt + 1;
                        else
                            clk_cnt  <= 0;
                            sclk_reg <= not sclk_reg;

                            -- Передній фронт SCLK (0 -> 1): зчитуємо біт з лінії MISO
                            if sclk_reg = '0' then
                                rx_shift <= rx_shift(6 downto 0) & miso;
                            
                            -- Задній фронт SCLK (1 -> 0): виставляємо наступний біт на MOSI
                            else
                                if bit_cnt > 0 then
                                    bit_cnt  <= bit_cnt - 1;
                                    tx_shift <= tx_shift(6 downto 0) & '0';
                                    mosi     <= tx_shift(6);
                                else
                                    state <= DONE_STATE;
                                end if;
                            end if;
                        end if;

                    -- 4. Завершення транзакції та фіксація прийнятого байта
                    when DONE_STATE =>
                        ss_n     <= '1';
                        sclk_reg <= '0';
                        mosi     <= '0';
                        rx_data  <= rx_shift;
                        done     <= '1';
                        busy     <= '0';
                        state    <= IDLE;
                end case;
            end if;
        end if;
    end process;

end Behavioral;