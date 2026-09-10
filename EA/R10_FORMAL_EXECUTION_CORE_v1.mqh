// R10 FORMAL EXECUTION CORE v1.0
// Intended integration point: EA/EAGOLD.mq4
// Pipeline: MEASURE -> CLASSIFY -> CANDIDATE -> SIMULATE -> HARD CONSTRAINTS
// -> LEXICOGRAPHIC RANK -> EXECUTE -> VERIFY -> RECONCILE -> EVENT

// This module is intentionally dependency-light. It expects the host EA to provide:
// DirectionLots(), DirectionBasketProfit(), ExposureLots(), NormalizeLot(),
// ReduceDirectionByLots(), CloseMarketOrderLots(), R10FindProfitFundedPair(),
// CreateR10VisualMarker(), Print(), Order/market helpers, and R10 inputs.

struct R10StateV1 {
   int heavy;
   int light;
   double buyLots;
   double sellLots;
   double netLots;
   double grossLots;
   double buyProfit;
   double sellProfit;
};

struct R10CandidateV1 {
   bool valid;
   int kind;                 // 1=pair, 2=balanced
   int direction;
   double lots;
   double expectedProfit;
   double simulatedExposure;
   double simulatedGross;
};

bool R10V1Measure(R10StateV1 &s){
   s.buyLots=DirectionLots(OP_BUY);
   s.sellLots=DirectionLots(OP_SELL);
   s.netLots=MathAbs(s.buyLots-s.sellLots);
   s.grossLots=s.buyLots+s.sellLots;
   s.buyProfit=DirectionBasketProfit(OP_BUY);
   s.sellProfit=DirectionBasketProfit(OP_SELL);
   s.heavy=-1; s.light=-1;
   if(s.buyLots>s.sellLots){s.heavy=OP_BUY;s.light=OP_SELL;}
   else if(s.sellLots>s.buyLots){s.heavy=OP_SELL;s.light=OP_BUY;}
   return(s.heavy>=0 && s.netLots+0.000001>=R10MinExposureLots);
}

bool R10V1LotValid(double lots){
   if(lots<Lot-0.000001)return(false);
   double minLot=MarketInfo(Symbol(),MODE_MINLOT);
   double maxLot=MarketInfo(Symbol(),MODE_MAXLOT);
   double step=MarketInfo(Symbol(),MODE_LOTSTEP);
   if(minLot>0.0 && lots<minLot-0.000001)return(false);
   if(maxLot>0.0 && lots>maxLot+0.000001)return(false);
   if(step>0.0 && minLot>0.0){
      double n=(lots-minLot)/step;
      if(MathAbs(n-MathRound(n))>0.000001)return(false);
   }
   return(true);
}

bool R10V1SimulateBalanced(const R10StateV1 &s,double lots,double &afterExposure,double &afterGross){
   if(lots<Lot || lots>s.netLots || s.light<0)return(false);
   double heavyLots=(s.heavy==OP_BUY?s.buyLots:s.sellLots);
   double lightLots=(s.light==OP_BUY?s.buyLots:s.sellLots);
   if(lots>heavyLots || lots>lightLots)return(false);
   afterExposure=MathAbs((heavyLots-lots)-(lightLots-lots));
   afterGross=s.grossLots-2.0*lots;
   return(R10V1LotValid(lots) && afterExposure<=s.netLots+0.000001 && afterGross<s.grossLots-0.000001);
}

bool R10V1SimulatePair(const R10StateV1 &s,int direction,double lots,double &afterExposure,double &afterGross){
   if(lots<Lot || !R10V1LotValid(lots))return(false);
   double b=s.buyLots, ss=s.sellLots;
   if(direction==OP_BUY)b-=lots; else if(direction==OP_SELL)ss-=lots; else return(false);
   if(b< -0.000001 || ss< -0.000001)return(false);
   afterExposure=MathAbs(b-ss);
   afterGross=b+ss;
   // HARD CONSTRAINT: a reduction must never increase net exposure.
   return(afterExposure<=s.netLots+0.000001 && afterGross<s.grossLots-0.000001);
}

bool R10V1HardConstraints(const R10StateV1 &s,const R10CandidateV1 &c){
   if(!c.valid || c.lots<Lot)return(false);
   if(!R10V1LotValid(c.lots))return(false);
   if(c.simulatedExposure>s.netLots+0.000001)return(false);
   if(c.simulatedGross>=s.grossLots-0.000001)return(false);
   return(true);
}

bool R10V1Verify(double beforeExposure,double beforeGross,double expectedGrossReduction,double &afterExposure,double &afterGross){
   afterExposure=ExposureLots();
   afterGross=DirectionLots(OP_BUY)+DirectionLots(OP_SELL);
   if(afterExposure>beforeExposure+0.00001)return(false);
   if(afterGross>=beforeGross-0.000001)return(false);
   if(expectedGrossReduction>0.0 && MathAbs((beforeGross-afterGross)-expectedGrossReduction)>MathMax(0.00001,Lot*0.25))return(false);
   return(true);
}
