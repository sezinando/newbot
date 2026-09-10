#ifndef EAGOLD_STATE_MQH
#define EAGOLD_STATE_MQH
// EAGOLD runtime state and basic recovery-step state functions.
string EA_NAME="EAGOLD";
string PANEL_PREFIX="EAGOLD_BT_";
string R10_MARKER_PREFIX="EAGOLD_R10_MARKER_";
string ENGINE_MARKER_PREFIX="EAGOLD_ENGINE_";
string TELEMETRY_PREFIX="EAGOLD_TELEM_";
string STATE_PREFIX="EAGOLD_STATE_";
double g_panelMinProfit=0.0;
double g_panelMaxLots=0.0;
bool g_panelInitialized=false;
bool g_r9HedgeActive=false;
int g_r9ProcessedTickets[];
datetime g_r10LastAction=0;
string g_r1LastDecision="DISABLED";
string g_r1LastReason="";
datetime g_r1LastDecisionTime=0;
bool g_r10RecoveryCycleActive=false;
double g_r10RecoveryStartEquity=0.0;
double g_r10RecoveryWorstEquity=0.0;
double RecoveryStepForLevel(int level){double step=RecoveryMinDistance;if(level<0)level=0;if(EnableRecoveryStepMultiplier&&RecoveryStepMultiplier>1.0){for(int i=0;i<level;i++){step*=RecoveryStepMultiplier;if(RecoveryStepMax>0.0&&step>=RecoveryStepMax){step=RecoveryStepMax;break;}}}if(RecoveryStepMax>0.0&&step>RecoveryStepMax)step=RecoveryStepMax;return(step);}
int RecoveryLevel(int direction){int count=CountDirectionPositions(direction);if(count<=1)return(0);return(count-1);}
#endif
