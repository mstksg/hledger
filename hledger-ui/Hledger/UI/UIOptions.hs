{-# LANGUAGE CPP #-}
{-|

-}

module Hledger.UI.UIOptions
where
import Data.Default
#if !MIN_VERSION_base(4,8,0)
import Data.Functor.Compat ((<$>))
#endif
import Data.List (intercalate)

import Hledger.Cli hiding (progname,version,prognameandversion)
import Hledger.UI.Theme (themeNames)

progname, version :: String
progname = "hledger-ui"
#ifdef VERSION
version = VERSION
#else
version = ""
#endif
prognameandversion :: String
prognameandversion = progname ++ " " ++ version :: String

uiflags = [
  -- flagNone ["debug-ui"]  (\opts -> setboolopt "rules-file" opts) "run with no terminal output, showing console"
   flagNone ["watch"] (\opts -> setboolopt "watch" opts) "watch for data and date changes and reload automatically"
  ,flagReq  ["theme"] (\s opts -> Right $ setopt "theme" s opts) "THEME" ("use this custom display theme ("++intercalate ", " themeNames++")")
  ,flagReq  ["register"] (\s opts -> Right $ setopt "register" s opts) "ACCTREGEX" "start in the (first) matched account's register"
  ,flagNone ["change"] (\opts -> setboolopt "change" opts)
    "show period balances (changes) at startup instead of historical balances"
  -- ,flagNone ["cumulative"] (\opts -> setboolopt "cumulative" opts)
  --   "show balance change accumulated across periods (in multicolumn reports)"
  -- ,flagNone ["historical","H"] (\opts -> setboolopt "historical" opts)
  --   "show historical ending balance in each period (includes postings before report start date)\n "
  ,flagNone ["flat"] (\opts -> setboolopt "flat" opts) "show full account names, unindented"
  -- ,flagReq ["drop"] (\s opts -> Right $ setopt "drop" s opts) "N" "with --flat, omit this many leading account name components"
  -- ,flagReq  ["format"] (\s opts -> Right $ setopt "format" s opts) "FORMATSTR" "use this custom line format"
  -- ,flagNone ["no-elide"] (\opts -> setboolopt "no-elide" opts) "don't compress empty parent accounts on one line"
 ]

--uimode :: Mode [([Char], [Char])]
uimode =  (mode "hledger-ui" [("command","ui")]
            "browse accounts, postings and entries in a full-window curses interface"
            (argsFlag "[PATTERNS]") []){
              modeGroupFlags = Group {
                                groupUnnamed = uiflags
                               ,groupHidden = []
                               ,groupNamed = [(generalflagsgroup1)]
                               }
             ,modeHelpSuffix=[
                  -- "Reads your ~/.hledger.journal file, or another specified by $LEDGER_FILE or -f, and starts the full-window curses ui."
                 ]
           }

-- hledger-ui options, used in hledger-ui and above
data UIOpts = UIOpts {
     watch_   :: Bool
    ,change_  :: Bool
    ,cliopts_ :: CliOpts
 } deriving (Show)

defuiopts = UIOpts
    def
    def
    def

-- instance Default CliOpts where def = defcliopts

rawOptsToUIOpts :: RawOpts -> IO UIOpts
rawOptsToUIOpts rawopts = checkUIOpts <$> do
  cliopts <- rawOptsToCliOpts rawopts
  return defuiopts {
              watch_   = boolopt "watch" rawopts
             ,change_  = boolopt "change" rawopts
             ,cliopts_ = cliopts
             }

checkUIOpts :: UIOpts -> UIOpts
checkUIOpts opts =
  either optserror (const opts) $ do
    case maybestringopt "theme" $ rawopts_ $ cliopts_ opts of
      Just t | not $ elem t themeNames -> Left $ "invalid theme name: "++t
      _                                -> Right ()

getHledgerUIOpts :: IO UIOpts
getHledgerUIOpts = processArgs uimode >>= return . decodeRawOpts >>= rawOptsToUIOpts

