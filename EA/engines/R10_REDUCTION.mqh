// EAGOLD R10 REDUCTION ENGINE v1.0
// Modular wrapper for the formal R10 execution core.
// Host dependencies are supplied by EAGOLD.mq4.

#ifndef EAGOLD_R10_REDUCTION_MQH
#define EAGOLD_R10_REDUCTION_MQH

#include "../R10_FORMAL_EXECUTION_CORE_v1.mqh"

// Runtime heartbeat/state used by the panel.
bool g_r10EngineLoaded=false;
bool g_r10EngineActive=false;
string g_r10EngineAction="BOOT";
string g_r10EngineReason="";
datetime g_r10EngineLastCall=0;
int g_r10EngineCalls=0;

void R10EngineSetStatus(string action,string reason){
   g_r10EngineActive=true;
   g_r10EngineAction=action;
   g_r10EngineReason=reason;
   g_r10EngineLastCall=TimeCurrent();
   g_r10EngineCalls++;
}

void R10EngineInit(){
   g_r10EngineLoaded=true;
   g_r10EngineActive=false;
   g_r10EngineAction="READY";
   g_r10EngineReason="MODULE_LOADED";
   g_r10EngineLastCall=0;
   g_r10EngineCalls=0;
}

void R10EngineHeartbeat(){
   if(!g_r10EngineLoaded) return;
   if(!EnableR10Reduce){
      R10EngineSetStatus("OFF","ENABLE_R10_REDUCE=false");
      return;
   }
   R10StateV1 state;
   bool measurable=R10V1Measure(state);
   if(!measurable){
      g_r10EngineActive=true;
      g_r10EngineAction="HOLD";
      g_r10EngineReason="NO_VALID_REDUCTION_STATE";
      g_r10EngineLastCall=TimeCurrent();
      g_r10EngineCalls++;
      return;
   }
   R10EngineSetStatus("HOLD","STATE_MEASURED");
}

string R10EngineStatusText(){
   if(!g_r10EngineLoaded) return("R10 FORMAL: OFF");
   if(!EnableR10Reduce) return("R10 FORMAL: LOADED / REDUCE OFF");
   if(g_r10EngineActive) return("R10 FORMAL: ACTIVE");
   return("R10 FORMAL: LOADED");
}

string R10EngineActionText(){
   if(!g_r10EngineLoaded) return("R10 ACTION: --");
   return("R10 ACTION: "+g_r10EngineAction);
}

#endif
