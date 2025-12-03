library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ball_controller is
    port(
        clk         : in std_logic;
        reset       : in std_logic;
        tick_60hz   : in std_logic; --VSYNC

        -- PADDLES
        p1_y_in     : in integer;
        p2_y_in     : in integer;

        -- Physics (Switches)
        gravity_sel    : in std_logic_vector(1 downto 0); 
        elasticity_sel  : in std_logic;

        -- Output for RENDERER
        ball_x_out  : out integer;
        ball_y_out  : out integer;

        -- Output for SCOREBOARD
        score1_out  : out integer;
        score2_out  : out integer
    );
end ball_controller;

architecture behavioral of ball_controller is

    -- Ponto Fixo Q12.6
    -- Multiplicamos tudo por 64 (2^6) para ter precisão de decimais
    -- 1 Pixel Real = 64 Unidades Lógicas
    
    constant FRAC_BITS : integer := 6; 
    
    -- Screen scale 64x
    constant SCREEN_W_FIXED : signed(17 downto 0) := to_signed(640 * 64, 18);
    constant SCREEN_H_FIXED : signed(17 downto 0) := to_signed(480 * 64, 18);
    
    -- Object sizes (x64)
    constant BALL_SIZE   : integer := 10;
    constant BALL_S_FIX  : signed(17 downto 0) := to_signed(10 * 64, 18);
    constant PADDLE_W    : integer := 10;
    constant PADDLE_H    : integer := 60;
    constant P1_X_POS    : integer := 50;  -- X position Paddle 1
    constant P2_X_POS    : integer := 590; -- X position Paddle 2

    -- Ball state
    signal pos_x, pos_y : signed(17 downto 0);
    signal vel_x, vel_y : signed(17 downto 0);

    -- Score
    signal s1, s2 : integer range 0 to 9 := 0;

    signal gravity_val : signed(17 downto 0);
    signal vsync_prev : std_logic := '0';

begin

    with gravity_sel select
        gravity_val <= to_signed(0, 18)  when "00",
                       to_signed(3, 18)  when "01",
                       to_signed(6, 18)  when "10",
                       to_signed(12, 18) when others;

    process(clk, reset)
        -- Variáveis temporárias para facilitar a detecção de colisão
        variable b_left, b_right, b_top, b_bot : integer;
        variable p1_top, p1_bot, p2_top, p2_bot : integer;
        variable hit_pos : integer;
    begin
        if reset = '0' then
            -- Resetar ball to center
            pos_x <= to_signed(320 * 64, 18);
            pos_y <= to_signed(240 * 64, 18);
            vel_x <= to_signed(200, 18);  
            vel_y <= to_signed(-150, 18);
            -- Resetar Placar
            s1 <= 0; s2 <= 0;
            vsync_prev <= '0';

        elsif rising_edge(clk) then

            if (tick_60hz = '1' and vsync_prev = '0') then

                vel_y <= vel_y + gravity_val;
                pos_x <= pos_x + vel_x;
                pos_y <= pos_y + vel_y;

                b_left   := to_integer(pos_x) / 64;
                b_right  := b_left + BALL_SIZE;
                b_top    := to_integer(pos_y) / 64;
                b_bot    := b_top + BALL_SIZE;
                
                p1_top := p1_y_in; 
                p1_bot := p1_y_in + PADDLE_H;
                p2_top := p2_y_in;
                p2_bot := p2_y_in + PADDLE_H;

                -- COLISION TOP (Y=0)
                if (b_top <= 0) and (vel_y < 0) then
                    vel_y <= abs(vel_y);
                    if elasticity_sel = '1' then
                        vel_y <= - (vel_y - (vel_y / 4)); -- vel = 75% vel  
                    else
                        vel_y <= -vel_y;
                    end if;
                end if;

                -- COLISION BOTTOM (Y=480)
                if (b_bot >= 480) and (vel_y > 0) then
                    if elasticity_sel = '1' then
                        vel_y <= - (vel_y - (vel_y / 4)); -- vel = 75% vel  
                    else
                        vel_y <= -vel_y;
                    end if;
                end if;

                -- COLISION PADDLE 1
                if (b_left <= P1_X_POS + PADDLE_W) and (b_left >= P1_X_POS) then
                    if (b_bot >= p1_top) and (b_top <= p1_bot) then
                        if vel_x < 0 then
                            vel_x <= abs(vel_x);
                            hit_pos := (b_top + 5) - p1_top;
                            if (hit_pos < 17) then
                                vel_y <= to_signed(-250, 18);
                                
                            elsif (hit_pos > 33) then
                                vel_y <= to_signed(250, 18);
                            end if;
                        end if; 
                    end if;
                end if;

                -- COLISION PADDLE 2
                if (b_right >= P2_X_POS) and (b_right <= P2_X_POS + PADDLE_W) then
                    if (b_bot >= p2_top) and (b_top <= p2_bot) then
                        if vel_x > 0 then
                            vel_x <= -abs(vel_x);
                            hit_pos := (b_top + 5) - p2_top;  
                            if (hit_pos < 17) then
                                vel_y <= to_signed(-250, 18);
                            elsif (hit_pos > 33) then
                                vel_y <= to_signed(250, 18);
                            end if;
                        end if;
                    end if;
                end if;

                if (b_left <= 0) then -- Score Player 2
                    if s2 < 9 then s2 <= s2 + 1; end if;
                    -- Reset ball
                    pos_x <= to_signed(320 * 64, 18);
                    pos_y <= to_signed(240 * 64, 18);
                    vel_x <= to_signed(200, 18); -- Reinicia devagar
                    
                elsif (b_right >= 640) then -- Score Player 1
                    if s1 < 9 then s1 <= s1 + 1; end if;
                    pos_x <= to_signed(320 * 64, 18);
                    pos_y <= to_signed(240 * 64, 18);
                    vel_x <= to_signed(-200, 18);
                end if;
            end if;
            vsync_prev <= tick_60hz;
        end if;
    end process;

    -- Converte Ponto Fixo (Q12.6) para Inteiro (Pixel)
    ball_x_out <= to_integer(pos_x(17 downto 6));
    ball_y_out <= to_integer(pos_y(17 downto 6));

    score1_out <= s1;
    score2_out <= s2;

end behavioral;