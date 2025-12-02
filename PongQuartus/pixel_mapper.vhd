library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--
-- pixel_mapper.vhd
-- Small reusable component that maps (col, row) -> pixel_color for a black-background Pong game
-- Outputs '1' for white pixels (ball or paddles) and '0' for black background.
--

entity pixel_mapper is
    generic (
        SCREEN_W      : integer := 640;  -- screen width in pixels
        SCREEN_H      : integer := 480;  -- screen height in pixels
        BALL_SIZE     : integer := 10;   -- size of the ball (requested default = 10)
        PADDLE_WIDTH  : integer := 10;   -- paddle width in pixels (tweakable)
        PADDLE_HEIGHT : integer := 50;   -- paddle height in pixels (tweakable)
        LEFT_PADDLE_X : integer := 50;   -- X position of left paddle
        RIGHT_PADDLE_X: integer := 590   -- X position of right paddle (default near right edge)
    );

    port (
        paddle_left_y_in  : in integer;  -- center/top (use whatever convention you have)
        paddle_right_y_in : in integer;  -- paddle Y positions
        ball_x_out        : in integer;  -- ball X,Y position (top-left of ball box)
        ball_y_out        : in integer;
        coluna            : in std_logic_vector(9 downto 0); -- pixel column (x)
        linha             : in std_logic_vector(9 downto 0); -- pixel row    (y)
        pixel_color       : out std_logic  -- 1=white (foreground), 0=black (background)
    );
end pixel_mapper;

architecture rtl of pixel_mapper is

    -- convert vectors to integers for comparison
    signal x_coord : integer range 0 to SCREEN_W := 0;
    signal y_coord : integer range 0 to SCREEN_H := 0;

begin

    -- convert inputs once (combinational)
    x_coord <= to_integer(unsigned(coluna));
    y_coord <= to_integer(unsigned(linha));

    -- combinational detection of ball/paddles
    process(x_coord, y_coord, paddle_left_y_in, paddle_right_y_in, ball_x_out, ball_y_out)
        variable ball_hit        : boolean;
        variable left_paddle_hit : boolean;
        variable right_paddle_hit: boolean;
        variable px              : integer;
        variable py              : integer;
    begin
        px := x_coord;
        py := y_coord;

        -- Ball rectangle
        ball_hit := false;
        if (ball_x_out < SCREEN_W) and (ball_y_out < SCREEN_H) then
            if (px >= ball_x_out) and (px < ball_x_out + BALL_SIZE) and
               (py >= ball_y_out) and (py < ball_y_out + BALL_SIZE) then
                ball_hit := true;
            end if;
        end if;

        -- Left paddle rectangle
        left_paddle_hit := false;
        if (paddle_left_y_in >= 0) then
            if (px >= LEFT_PADDLE_X) and (px < LEFT_PADDLE_X + PADDLE_WIDTH) and
               (py >= paddle_left_y_in) and (py < paddle_left_y_in + PADDLE_HEIGHT) then
                left_paddle_hit := true;
            end if;
        end if;

        -- Right paddle rectangle
        right_paddle_hit := false;
        if (paddle_right_y_in >= 0) then
            if (px >= RIGHT_PADDLE_X) and (px < RIGHT_PADDLE_X + PADDLE_WIDTH) and
               (py >= paddle_right_y_in) and (py < paddle_right_y_in + PADDLE_HEIGHT) then
                right_paddle_hit := true;
            end if;
        end if;

        -- white if any foreground object; otherwise black
        if ball_hit or left_paddle_hit or right_paddle_hit then
            pixel_color <= '1';
        else
            pixel_color <= '0';
        end if;
    end process;

end rtl;
