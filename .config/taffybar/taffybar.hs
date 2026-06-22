import Control.Concurrent.MVar
import Control.Monad
import Control.Monad.IO.Class
import Control.Monad.Reader.Class
import Control.Monad.Trans.Class
import Data.Int
import Data.List
import Data.List.Utils (replace)
import qualified Data.Map as M
import qualified Data.Text as T
import qualified GI.Gtk as Gtk
import qualified GI.Gdk as Gdk
import System.Directory
import System.Posix.Signals
import System.Process
import System.Taffybar
import System.Taffybar.Context (TaffyIO)
import System.Taffybar.SimpleConfig
import System.Taffybar.Widget.CommandRunner
import System.Taffybar.Widget.Layout
import System.Taffybar.Widget.SimpleClock
import System.Taffybar.Widget.Util
import System.Taffybar.Widget.Windows
import System.Taffybar.Widget.Workspaces
import System.Taffybar.Information.EWMHDesktopInfo

wrap :: String -> String -> String -> String
wrap start end text = start ++ text ++ end

fontAwesomeMarkup :: String -> String
fontAwesomeMarkup = wrap "<span font='Font Awesome 6 Free Solid'>" "</span>"

replaceAll :: String -> [(String, String)] -> String
replaceAll s transformations =
    foldr ($) s $ map (\(from, to) -> replace from to) transformations

workspaceRename :: String -> String
workspaceRename s = replaceAll s $
    [ ("\x00a0"  , "")
    , ("web"     , fontAwesomeMarkup "\xf0ac") -- fa-globe
    , ("dev"     , fontAwesomeMarkup "\xf121") -- fa-code
    , ("ops"     , fontAwesomeMarkup "\xf120") -- fa-terminal
    , ("music"   , fontAwesomeMarkup "\xf001") -- fa-music
    , ("mail"    , fontAwesomeMarkup "\xf0e0") -- fa-envelope
    , ("chat"    , fontAwesomeMarkup "\xf075") -- fa-comment
    , ("windows" , fontAwesomeMarkup "\xf17a") -- fa-windows
    ] ++ (map (\s -> (s, fontAwesomeMarkup "\xf069")) unnamed)  -- fa-asterisk
  where
    unnamed = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]

workspaceDecorator :: String -> String -> Bool -> String -> String
workspaceDecorator fg bg bold s =
    (colorize fg bg . fontWeight . wrap " " " " . workspaceRename $ s) ++ endSep
  where
    fontWeight
      | bold      = wrap "<b>" "</b>"
      | otherwise = id
    endSep
      | '\x00a0' `notElem` s = ""
      | otherwise            = colorize bg "#000000" "\xe0b0 "

workspaceLabel :: Workspace -> [(WorkspaceId, Workspace)] -> String
workspaceLabel workspace occupiedWorkspaces
  | occupiedWorkspaces == [] = ""
  | otherwise =
        case workspaceState workspace of
            Active    -> workspaceDecorator "#282828" "#7cafc2" True name
            Visible   -> workspaceDecorator "#d8d8d8" "#383838" False name
            Hidden    -> workspaceDecorator "#d8d8d8" "#282828" False name
            Urgent    -> workspaceDecorator "#282828" "#f7ca88" False name
            otherwise -> ""
      where
        (lastWsIdx, _)            = last occupiedWorkspaces
        wsIdx@(WorkspaceId wsNum) = workspaceIdx workspace
        endMarker                 = if wsIdx == lastWsIdx then "\x00a0" else ""
        name                      = (show $ wsNum + 1) ++ ": " ++ workspaceName workspace ++ endMarker

workspaceLabelSetter :: Workspace -> WorkspacesIO String
workspaceLabelSetter workspace = do
    workspacesRef <- asks workspacesVar
    workspaces    <- lift $ readMVar workspacesRef
    let occupiedWorkspaces = filter (\(_, w) -> workspaceState w /= Empty) $ M.toList workspaces
    return $ workspaceLabel workspace occupiedWorkspaces

workspacesConfig :: WorkspacesConfig
workspacesConfig = defaultWorkspacesConfig
    { widgetBuilder        = buildButtonController buildLabelController
    , labelSetter          = workspaceLabelSetter
    , showWorkspaceFn      = hideEmpty
    , urgentWorkspaceState = True
    }

windowsConfig :: WindowsConfig
windowsConfig = defaultWindowsConfig
    { getActiveLabel = activeWindowLabeler }
  where
    activeWindowLabeler = do
      label <- truncatedGetActiveLabel 100
      return . T.pack . wrap " " " " . T.unpack $ label

statusWidget :: String -> TaffyIO Gtk.Widget
statusWidget cmd = do
    dataDir <- liftIO $ getXdgDirectory XdgConfig "taffybar"
    commandRunnerNew 0 (dataDir ++ "/status-read") [cmd] $ T.pack ""

taffybarConfig :: SimpleTaffyConfig
taffybarConfig = defaultSimpleTaffyConfig
    { monitorsAction = return [0]
    , startWidgets   = [workspaces, windows]
    , endWidgets     = clock : statusWidgets
    , barHeight      = ExactSize 18
    , widgetSpacing  = 0
    }
  where
    workspaces    = workspacesNew Main.workspacesConfig
    windows       = windowsNew windowsConfig
    clock         = textClockNew Nothing ((colorize "#383838" "#282828" "\xe0b2") ++ (colorize "#d8d8d8" "#383838" " %a %b %_d %r ")) 1
    statusWidgets = map statusWidget ["vpn", "screensaver", "backlight", "audio", "network", "power", "load"]

main :: IO ()
main = simpleTaffybar taffybarConfig

-- vim: filetype=haskell
