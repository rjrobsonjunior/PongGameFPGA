LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY quadrado_ctrl IS
    PORT (
        sw_control : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
        coluna     : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
        linha      : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
        a          : OUT STD_LOGIC
    );
END quadrado_ctrl;

ARCHITECTURE rtl OF quadrado_ctrl IS
    SIGNAL pos_x, pos_y : INTEGER RANGE 0 TO 639;
    SIGNAL col_int, lin_int : INTEGER RANGE 0 TO 639;
BEGIN

    -- Conversão dos sinais de entrada para inteiros
    col_int <= to_integer(unsigned(coluna));
    lin_int <= to_integer(unsigned(linha));

    -- Cálculo da posição do quadrado com base nos switches
    pos_x <= to_integer(unsigned(sw_control(3 DOWNTO 0))) * 40;
    pos_y <= to_integer(unsigned(sw_control(7 DOWNTO 4))) * 30;

    PROCESS(col_int, lin_int, pos_x, pos_y)
    BEGIN
        -- Desenha o quadrado 10x10
        IF (col_int >= pos_x AND col_int < pos_x + 10 AND
            lin_int >= pos_y AND lin_int < pos_y + 10) THEN
            a <= '1';
        ELSE
            a <= '0';
        END IF;
    END PROCESS;

END rtl;
