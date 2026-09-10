// EAGOLD R10 STATUS PANEL v1.0
// Optional UI adapter. Call R10PanelStatusUpdate(row) from PanelUpdate().

#ifndef EAGOLD_R10_STATUS_MQH
#define EAGOLD_R10_STATUS_MQH

void R10PanelStatusUpdate(int &row){
   color statusColor=clrSilver;
   if(g_r10EngineLoaded && EnableR10Reduce) statusColor=clrLime;
   else if(g_r10EngineLoaded) statusColor=clrYellow;

   PanelSet("R10",R10EngineStatusText(),row++,statusColor);
   PanelSet("R10P",R10EngineActionText(),row++,
            g_r10EngineAction=="REDUCE"?clrLime:
            (g_r10EngineAction=="BLOCK"?clrTomato:clrSilver));
}

#endif
