wvCreateWindow
wvSetPosition -win $_nWave2 {("G1" 0)}
wvOpenFile -win $_nWave2 \
           {/fetools/work_area/frontend/Batch_10/ayan/PROJECTS/apb_i2c_controller/sim/synopsys_sim/novas.fsdb}
wvSetFileTimeRange -win $_nWave2 -time_unit 1p 0 3970000
wvGetSignalOpen -win $_nWave2
wvGetSignalSetScope -win $_nWave2 "/_\$novas_unit__1"
wvGetSignalSetScope -win $_nWave2 \
           "/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h"
wvGetSignalSetScope -win $_nWave2 \
           "/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf"
wvSetPosition -win $_nWave2 {("G1" 10)}
wvSetPosition -win $_nWave2 {("G1" 10)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/SCL} \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/SDA} \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/areset} \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/pclk} \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/scl_i} \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/scl_o} \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/scl_oen} \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/sda_i} \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/sda_o} \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/sda_oen} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 1 2 3 4 5 6 7 8 9 10 )} 
wvSetPosition -win $_nWave2 {("G1" 10)}
wvSetPosition -win $_nWave2 {("G1" 10)}
wvSetPosition -win $_nWave2 {("G1" 10)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/SCL} \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/SDA} \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/areset} \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/pclk} \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/scl_i} \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/scl_o} \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/scl_oen} \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/sda_i} \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/sda_o} \
{/hdl_top/i3c_target_agent_bfm\[0\]/i3c_target_agent_bfm_h/intf/sda_oen} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 1 2 3 4 5 6 7 8 9 10 )} 
wvSetPosition -win $_nWave2 {("G1" 10)}
wvGetSignalClose -win $_nWave2
verdiWindowBeWindow -win $_nWave2
wvResizeWindow -win $_nWave2 0 49 1536 263
wvSetCursor -win $_nWave2 546769.497336 -snap {("G1" 10)}
verdiDockWidgetMaximize -dock windowDock_OneSearch
verdiShowWindow -win $_Verdi_1 -switchFS
verdiWindowResize -win $_Verdi_1 "318" "49" "900" "700"
wvResizeWindow -win $_nWave2 -3 49 1536 715
wvSetCursor -win $_nWave2 325711.205169 -snap {("G2" 0)}
wvSelectGroup -win $_nWave2 {G2}
verdiWindowRaise -win $_nWave2
wvResizeWindow -win $_nWave2 0 49 1536 263
verdiWindowRaise -win $_Verdi_1
verdiWindowRaise -win $_nWave2
wvTpfCloseForm -win $_nWave2
wvGetSignalClose -win $_nWave2
wvCloseWindow -win $_nWave2
debExit
