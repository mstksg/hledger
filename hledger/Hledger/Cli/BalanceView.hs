{-# LANGUAGE OverloadedStrings, RecordWildCards, ViewPatterns #-}
{-|

This module is used by the 'balancesheet', 'incomestatement', and
'cashflow' commands to print out acocunt balances based on a specific
"view", which consists of a title and multiple named queries that are
aggregated and totaled.

-}

module Hledger.Cli.BalanceView (
  BalanceView(..)
 ,balanceviewmode
 ,balanceviewReport
) where

import Control.Monad (unless)
import Data.List (intercalate, foldl')
import Data.Monoid (Sum(..), (<>))
import System.Console.CmdArgs.Explicit as C
import Text.Tabular as T

import Hledger
import Hledger.Cli.Balance
import Hledger.Cli.CliOptions

-- | Describes a view for the balance, which can consist of multiple
-- separate named queries that are aggregated and totaled.
data BalanceView = BalanceView {
      bvmode     :: String,                        -- ^ command line mode of the view
      bvaliases  :: [String],                      -- ^ command line aliases
      bvhelp     :: String,                        -- ^ command line help message
      bvtitle    :: String,                        -- ^ title of the view
      bvqueries  :: [(String, Journal -> Query)],  -- ^ named queries that make up the view
      bvtype     :: BalanceType                    -- ^ the type of balance this view shows.
                                                   --   This overrides user input.
}

balanceviewmode :: BalanceView -> Mode RawOpts
balanceviewmode BalanceView{..} = (defCommandMode $ bvmode : bvaliases) {
  modeHelp = bvhelp `withAliases` bvaliases
 ,modeGroupFlags = C.Group {
     groupUnnamed = [
      flagNone ["flat"] (\opts -> setboolopt "flat" opts) "show accounts as a list"
     ,flagReq  ["drop"] (\s opts -> Right $ setopt "drop" s opts) "N" "flat mode: omit N leading account name parts"
     ,flagNone ["no-total","N"] (\opts -> setboolopt "no-total" opts) "omit the final total row"
     ,flagNone ["no-elide"] (\opts -> setboolopt "no-elide" opts) "don't squash boring parent accounts (in tree mode)"
     ,flagReq  ["format"] (\s opts -> Right $ setopt "format" s opts) "FORMATSTR" "use this custom line format (in simple reports)"
     ]
    ,groupHidden = []
    ,groupNamed = [generalflagsgroup1]
    }
 }

balanceviewQueryReport
    :: ReportOpts
    -> Query
    -> Journal
    -> String
    -> (Journal -> Query)
    -> ([String], Sum MixedAmount)
balanceviewQueryReport ropts q0 j t q = ([view], Sum amt)
    where
      q' = And [q0, q j]
      rep@(_ , amt) = balanceReport ropts q' j
      view = intercalate "\n" [t <> ":", balanceReportAsText ropts rep]

multiBalanceviewQueryReport
    :: ReportOpts
    -> Query
    -> Journal
    -> String
    -> (Journal -> Query)
    -> ([Table String String MixedAmount], [[MixedAmount]], Sum MixedAmount, Sum MixedAmount)
multiBalanceviewQueryReport ropts q0 j t q = ([tabl], [coltotals], Sum tot, Sum avg)
    where
      q' = And [q0, q j]
      r@(MultiBalanceReport (_, _, (coltotals,tot,avg))) =
          multiBalanceReport ropts q' j
      Table hLeft hTop dat = balanceReportAsTable ropts r
      tabl = Table (T.Group SingleLine [Header t, hLeft]) hTop ([]:dat)

-- | Prints out a balance report according to a given view
balanceviewReport :: BalanceView -> CliOpts -> Journal -> IO ()
balanceviewReport BalanceView{..} CliOpts{reportopts_=ropts} j = do
    currDay   <- getCurrentDay
    let q0 = case bvtype of
               HistoricalBalance -> queryFromOpts currDay (withoutBeginDate ropts')
               _                 -> queryFromOpts currDay ropts
    case interval_ ropts' of
      NoInterval -> do
        let (views, amt) =
              foldMap (uncurry (balanceviewQueryReport ropts' q0 j))
                 bvqueries
        mapM_ putStrLn (bvtitle : "" : views)

        unless (no_total_ ropts') . mapM_ putStrLn $
          [ "Total:"
          , "--------------------"
          , padleft 20 $ showMixedAmountWithoutPrice (getSum amt)
          ]
      _ -> do
        let (tabls, amts, Sum totsum, Sum totavg)
              = foldMap (uncurry (multiBalanceviewQueryReport ropts' q0 j)) bvqueries
            sumAmts = case amts of
              a1:as -> foldl' (zipWith (+)) a1 as
              []    -> []
            mergedTabl = case tabls of
              t1:ts -> foldl' merging t1 ts
              []    -> T.empty
            totTabl | no_total_ ropts' = mergedTabl
                    | otherwise        =
                mergedTabl
                +====+
                row "Total"
                    (sumAmts ++ if row_total_ ropts' then [totsum] else []
                             ++ if average_   ropts' then [totavg] else []
                    )
        putStrLn bvtitle
        putStrLn $ renderBalanceReportTable (alignBalanceReportTable totTabl)
  where
    ropts' = ropts { balancetype_ = bvtype }
    merging (Table hLeft hTop dat) (Table hLeft' _ dat') =
        Table (T.Group DoubleLine [hLeft, hLeft']) hTop (dat ++ dat')


-- multiBalanceviewReport :: BalanceView -> CliOpts -> Journal -> IO ()
-- multiBalanceviewReport BalanceView{..} CliOpts{reportopts_=ropts} j = do


withoutBeginDate :: ReportOpts -> ReportOpts
withoutBeginDate ropts@ReportOpts{..} = ropts{period_=p}
  where
    p = dateSpanAsPeriod $ DateSpan Nothing (periodEnd period_)

