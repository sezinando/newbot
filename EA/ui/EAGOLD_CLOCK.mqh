#ifndef EAGOLD_CLOCK_MQH
#define EAGOLD_CLOCK_MQH

//==================================================================
// EAGOLD CLOCK
// SERVER = broker/server time (TimeCurrent)
// GMT-3  = fixed UTC-3 time (TimeGMT - 3 hours)
//==================================================================
extern bool EnableEAGOLDClock=true;
extern int EAGOLDClockX=12;
extern int EAGOLDClockY=18;
extern int EAGOLDClockFontSize=10;
extern color EAGOLDClockColor=clrWhite;

string EAGOLD_CLOCK_OBJECT="EAGOLD_CLOCK";

void EAGOLDClockUpdate()
{
   if(!EnableEAGOLDClock)
   {
      if(ObjectFind(0,EAGOLD_CLOCK_OBJECT)>=0)
         ObjectDelete(0,EAGOLD_CLOCK_OBJECT);
      return;
   }

   datetime serverTime=TimeCurrent();
   datetime gmt3Time=TimeGMT()-3*60*60;
   string text="SERVER  "+TimeToString(serverTime,TIME_DATE|TIME_SECONDS)+"   |   GMT-3  "+TimeToString(gmt3Time,TIME_DATE|TIME_SECONDS);

   if(ObjectFind(0,EAGOLD_CLOCK_OBJECT)<0)
   {
      ObjectCreate(0,EAGOLD_CLOCK_OBJECT,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,EAGOLD_CLOCK_OBJECT,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,EAGOLD_CLOCK_OBJECT,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
      ObjectSetString(0,EAGOLD_CLOCK_OBJECT,OBJPROP_FONT,"Consolas");
      ObjectSetInteger(0,EAGOLD_CLOCK_OBJECT,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,EAGOLD_CLOCK_OBJECT,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,EAGOLD_CLOCK_OBJECT,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,EAGOLD_CLOCK_OBJECT,OBJPROP_BACK,false);
   }

   ObjectSetInteger(0,EAGOLD_CLOCK_OBJECT,OBJPROP_XDISTANCE,EAGOLDClockX);
   ObjectSetInteger(0,EAGOLD_CLOCK_OBJECT,OBJPROP_YDISTANCE,EAGOLDClockY);
   ObjectSetInteger(0,EAGOLD_CLOCK_OBJECT,OBJPROP_FONTSIZE,EAGOLDClockFontSize);
   ObjectSetInteger(0,EAGOLD_CLOCK_OBJECT,OBJPROP_COLOR,EAGOLDClockColor);
   ObjectSetString(0,EAGOLD_CLOCK_OBJECT,OBJPROP_TEXT,text);
   ChartRedraw(0);
}

void EAGOLDClockInit()
{
   EventSetTimer(1);
   EAGOLDClockUpdate();
}

void EAGOLDClockDeinit()
{
   EventKillTimer();
   if(ObjectFind(0,EAGOLD_CLOCK_OBJECT)>=0)
      ObjectDelete(0,EAGOLD_CLOCK_OBJECT);
}

void EAGOLDClockTimer()
{
   EAGOLDClockUpdate();
}

#endif
