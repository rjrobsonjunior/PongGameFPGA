library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--
-- paddle_controller.vhd
-- Controlador de paddles usando 4 pushbuttons (2 por paddle)
-- Entradas: left_up, left_down (IO 0,1) e right_up, right_down (IO 14,15)
-- clk_60hz: taxa de atualização (60 Hz)
-- Saídas: posição Y dos paddles em formato integer
-- Esta versão adiciona: entrada síncrona de reset `rst` e debounce paramétrico
-- Assunção por padrão: botões conectados a GND com pull-up interno/externo (BTN_ACTIVE_LOW = true)
--

entity paddle_controller is
    generic (
        SCREEN_H       : integer := 480;   -- altura da tela
        PADDLE_HEIGHT  : integer := 50;    -- altura do paddle
        STEP           : integer := 2;     -- pixels por passo quando botão pressionado
        INIT_Y         : integer := 215;   -- posição inicial (conforme pedido)
        BTN_ACTIVE_LOW : boolean := true;  -- true se botões são conectados a GND (ativo-low)
        DEBOUNCE_BITS  : integer := 4      -- número de amostras para debounce (>=1)
    );
    port (
        clk_60hz           : in  std_logic; -- clock de atualização (60 Hz)
        rst                : in  std_logic; -- reset síncrono ativo-alto (reposiciona paddles para INIT_Y)
        left_up_btn        : in  std_logic; -- botão mover para cima (paddle esquerdo) - sinal bruto
        left_down_btn      : in  std_logic; -- botão mover para baixo (paddle esquerdo) - sinal bruto
        right_up_btn       : in  std_logic; -- botão mover para cima (paddle direito) - sinal bruto
        right_down_btn     : in  std_logic; -- botão mover para baixo (paddle direito) - sinal bruto
        paddle_left_y_out  : out integer; -- saída posição Y (integer)
        paddle_right_y_out : out integer
    );
end paddle_controller;

architecture rtl of paddle_controller is
    -- armazenar posições internas com limites apropriados
    signal left_y  : integer range 0 to SCREEN_H := INIT_Y;
    signal right_y : integer range 0 to SCREEN_H := INIT_Y;
    -- limites máximos (não deixar o paddle sair da tela)
    constant Y_MAX : integer := SCREEN_H - PADDLE_HEIGHT;

    -- registradores deslizantes para debounce (guardam últimas DEBOUNCE_BITS amostras)
    signal left_up_sr     : std_logic_vector(DEBOUNCE_BITS-1 downto 0) := (others => '1');
    signal left_down_sr   : std_logic_vector(DEBOUNCE_BITS-1 downto 0) := (others => '1');
    signal right_up_sr    : std_logic_vector(DEBOUNCE_BITS-1 downto 0) := (others => '1');
    signal right_down_sr  : std_logic_vector(DEBOUNCE_BITS-1 downto 0) := (others => '1');
    -- sinais estáveis (deboounced) em nível lógico '1' quando considerado pressionado
    signal left_up_deb    : std_logic := '0';
    signal left_down_deb  : std_logic := '0';
    signal right_up_deb   : std_logic := '0';
    signal right_down_deb : std_logic := '0';

begin

    -- Processo síncrono que faz: debounce das entradas e atualização das posições (sample em 60 Hz)
    process(clk_60hz)
        -- variáveis locais para comparação fácil
        variable all_active_level   : std_logic_vector(DEBOUNCE_BITS-1 downto 0);
        variable all_inactive_level : std_logic_vector(DEBOUNCE_BITS-1 downto 0);
    begin
        if rising_edge(clk_60hz) then
            -- inicializar valores de comparação (dependendo do nível ativo)
            if BTN_ACTIVE_LOW then
                all_active_level := (others => '0');
                all_inactive_level := (others => '1');
            else
                all_active_level := (others => '1');
                all_inactive_level := (others => '0');
            end if;

            -- reset síncrono: coloca paddles na posição inicial e limpa debounce para estado 'inativo'
            if rst = '0' then
                left_y  <= INIT_Y;
                right_y <= INIT_Y;
                left_up_sr    <= all_inactive_level;
                left_down_sr  <= all_inactive_level;
                right_up_sr   <= all_inactive_level;
                right_down_sr <= all_inactive_level;
                left_up_deb    <= '0';
                left_down_deb  <= '0';
                right_up_deb   <= '0';
                right_down_deb <= '0';
            else
                -- shift-in das amostras brutas (registrador deslizante)
                if DEBOUNCE_BITS > 1 then
                    left_up_sr    <= left_up_sr(DEBOUNCE_BITS-2 downto 0) & left_up_btn;
                    left_down_sr  <= left_down_sr(DEBOUNCE_BITS-2 downto 0) & left_down_btn;
                    right_up_sr   <= right_up_sr(DEBOUNCE_BITS-2 downto 0) & right_up_btn;
                    right_down_sr <= right_down_sr(DEBOUNCE_BITS-2 downto 0) & right_down_btn;
                else
                    -- caso DEBOUNCE_BITS = 1, simplesmente armazena o último valor
                    left_up_sr(0)    <= left_up_btn;
                    left_down_sr(0)  <= left_down_btn;
                    right_up_sr(0)   <= right_up_btn;
                    right_down_sr(0) <= right_down_btn;
                end if;

                -- atualizar sinais debounced: considerar pressionado quando todas as amostras estão no nível ativo
                if left_up_sr = all_active_level then
                    left_up_deb <= '1';
                elsif left_up_sr = all_inactive_level then
                    left_up_deb <= '0';
                end if;

                if left_down_sr = all_active_level then
                    left_down_deb <= '1';
                elsif left_down_sr = all_inactive_level then
                    left_down_deb <= '0';
                end if;

                if right_up_sr = all_active_level then
                    right_up_deb <= '1';
                elsif right_up_sr = all_inactive_level then
                    right_up_deb <= '0';
                end if;

                if right_down_sr = all_active_level then
                    right_down_deb <= '1';
                elsif right_down_sr = all_inactive_level then
                    right_down_deb <= '0';
                end if;

                -- Movimento dos paddles usando sinais debounced (tratados como active-high agora)
                -- Paddle esquerdo
                if (left_up_deb = '1') and (left_down_deb = '0') then
                    if left_y > STEP then
                        left_y <= left_y - STEP;
                    else
                        left_y <= 0;
                    end if;
                elsif (left_down_deb = '1') and (left_up_deb = '0') then
                    if left_y < Y_MAX - STEP then
                        left_y <= left_y + STEP;
                    else
                        left_y <= Y_MAX;
                    end if;
                else
                    left_y <= left_y;
                end if;

                -- Paddle direito
                if (right_up_deb = '1') and (right_down_deb = '0') then
                    if right_y > STEP then
                        right_y <= right_y - STEP;
                    else
                        right_y <= 0;
                    end if;
                elsif (right_down_deb = '1') and (right_up_deb = '0') then
                    if right_y < Y_MAX - STEP then
                        right_y <= right_y + STEP;
                    else
                        right_y <= Y_MAX;
                    end if;
                else
                    right_y <= right_y;
                end if;
            end if; -- rst
        end if; -- rising_edge
    end process;

    -- Saídas conectadas aos sinais internos
    paddle_left_y_out  <= left_y;
    paddle_right_y_out <= right_y;

end rtl;
