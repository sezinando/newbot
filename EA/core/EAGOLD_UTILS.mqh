#ifndef EAGOLD_UTILS_MQH
#define EAGOLD_UTILS_MQH
// EAGOLD identity, normalization, order counting and exposure primitives.
double PointsToPrice(double points){return(points*Point);}
double NormalizePrice(double price){return(NormalizeDouble(price,Digits));}
double NormalizeLot(double lot){if(lot<Lot)lot=Lot;if(MaxOpenLot>0.0&&lot>MaxOpenLot)lot=MaxOpenLot;return(NormalizeDouble(lot,DigitsLots));}
bool IsEAGOLDOrder(){return(OrderSymbol()==Symbol()&&OrderMagicNumber()==MagicNumber);}
int CountOrdersByType(int type){int count=0;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder())continue;if(OrderType()==type)count++;}return(count);}
int CountDirectionPositions(int direction){return(CountOrdersByType(direction==OP_BUY?OP_BUY:OP_SELL));}
int CountDirectionPending(int direction){return(CountOrdersByType(direction==OP_BUY?OP_BUYSTOP:OP_SELLSTOP));}
int CountEAGOLDOrders(){int count=0;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(IsEAGOLDOrder())count++;}return(count);}
double DirectionBasketProfit(int direction){int type=(direction==OP_BUY?OP_BUY:OP_SELL);double total=0.0;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder()||OrderType()!=type)continue;total+=OrderProfit()+OrderSwap()+OrderCommission();}return(total);}
double DirectionLots(int direction){int type=(direction==OP_BUY?OP_BUY:OP_SELL);double total=0.0;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder()||OrderType()!=type)continue;total+=OrderLots();}return(total);}
double ExposureLots(){return(MathAbs(DirectionLots(OP_BUY)-DirectionLots(OP_SELL)));}
int HeavyDirection(){double b=DirectionLots(OP_BUY),s=DirectionLots(OP_SELL);if(b>s)return(OP_BUY);if(s>b)return(OP_SELL);return(-1);}
double EAGOLDAccumulatedProfit(){double total=0.0;for(int i=OrdersHistoryTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))continue;if(!IsEAGOLDOrder())continue;int type=OrderType();if(type==OP_BUY||type==OP_SELL)total+=OrderProfit()+OrderSwap()+OrderCommission();}return(total);}
#endif
