import XMonad
import XMonad.Core
import qualified XMonad.StackSet as W

import XMonad.Actions.CycleWS
import XMonad.Actions.GroupNavigation
import XMonad.Actions.Navigation2D
import XMonad.Actions.PhysicalScreens
import XMonad.Actions.TopicSpace
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.EwmhDesktops
import XMonad.Hooks.InsertPosition
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.RefocusLast
import XMonad.Hooks.WorkspaceHistory
import XMonad.Layout.BoringWindows hiding (Replace)
import XMonad.Layout.Gaps
import XMonad.Layout.LayoutModifier
import XMonad.Layout.Maximize
import XMonad.Layout.MultiToggle
import XMonad.Layout.MultiToggle.Instances
import XMonad.Layout.NoBorders
import XMonad.Layout.PerWorkspace
import XMonad.Layout.Reflect
import XMonad.Layout.Renamed
import XMonad.Layout.ResizableTile
import XMonad.Layout.Simplest
import XMonad.Layout.Spacing
import XMonad.Layout.SubLayouts
import XMonad.Layout.Tabbed
import XMonad.Layout.WindowNavigation
import qualified XMonad.Util.ExtensibleState as XS
import XMonad.Util.EZConfig
import XMonad.Util.Run
import XMonad.Util.SpawnOnce
import XMonad.Util.Timer
import XMonad.Util.Ungrab
import XMonad.Util.WorkspaceCompare

import System.Taffybar.Support.PagerHints

import Control.Monad
import Data.List
import Data.Map
import Data.Monoid
import System.Directory

-- Wrapper for TimerId so it can be stored in ExtensibleState
data PanelTimer = PanelTimer TimerId deriving Typeable
instance ExtensionClass PanelTimer where
    initialValue = PanelTimer 0

isDesktop  = isInProperty "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_DESKTOP"
isDock     = isInProperty "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_DOCK"
isFloating = isInProperty "_NET_WM_STATE" "_NET_WM_STATE_ABOVE"
isOSD      = isInProperty "_NET_WM_WINDOW_TYPE" "_KDE_NET_WM_WINDOW_TYPE_ON_SCREEN_DISPLAY"
isTooltip  = isInProperty "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_TOOLTIP"

isOverlayWindow :: Query Bool
isOverlayWindow = do
    isNotification      <- isInProperty "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_NOTIFICATION"
    floatingVideoWindow <- className =? "zoom" <&&> title =? "zoom_linux_float_video_window"
    sharingToolbar      <- className =? "zoom" <&&> title =? "as_toolbar"
    sharingWindowFrame  <- title =? "cpt_frame_window"
    return $ isNotification || floatingVideoWindow || sharingToolbar || sharingWindowFrame

allWindowsByType :: Query Bool -> X [Window]
allWindowsByType query = withDisplay $ \display -> do
    (_, _, windows) <- asks theRoot >>= io . queryTree display
    filterM (runQuery query) windows

doWindowAction :: (Window -> X ()) -> ManageHook
doWindowAction action = ask >>= liftX . action >> idHook

raiseWindow' :: Window -> X ()
raiseWindow' window = withDisplay $ \display ->
    io $ raiseWindow display window

raiseOverlays :: X ()
raiseOverlays = allWindowsByType isOverlayWindow >>= mapM_ raiseWindow'

raisePanelTemporarily :: X ()
raisePanelTemporarily = do
    allWindowsByType isDock >>= mapM_ raiseWindow'
    startTimer 2 >>= XS.put . PanelTimer

sendToBottom :: Window -> X ()
sendToBottom window = withDisplay $ \display ->
    io $ lowerWindow display window

sendToJustAboveDesktop :: Window -> X ()
sendToJustAboveDesktop window = do
    sendToBottom window
    allWindowsByType isDesktop >>= mapM_ sendToBottom

topicConfig :: TopicConfig
topicConfig = def
    { defaultTopicAction = \topic -> return ()
    , topicActions = fromList $
        [ ("ops"    , (ask >>= spawn . terminal . config))
        , ("dev"    , spawn "code")
        , ("music"  , spawn "firefox -P music --kiosk https://music.youtube.com/")
        , ("mail"   , spawn "firefox --new-window https://mail.google.com/mail/u/0/#inbox")
        ]
    }

switchTopicHook :: X ()
switchTopicHook = do
    currentWorkspace <- gets (W.tag . W.workspace . W.current . windowset)
    history <- workspaceHistory
    case history of
        (lastWorkspace:_) -> when (currentWorkspace /= lastWorkspace) $ switchTopic' currentWorkspace
        otherwise         -> switchTopic' currentWorkspace

switchTopic' :: Topic -> X ()
switchTopic' topic = do
    wins <- gets (W.integrate' . W.stack . W.workspace . W.current . windowset)
    when (Data.List.null wins) $ topicAction topicConfig topic

physicalScreens :: X [Maybe ScreenId]
physicalScreens = withWindowSet $ \windowSet -> do
    let numScreens = length $ W.screens windowSet
    mapM (\s -> getScreen def (P s)) [0..numScreens]

-- If this function seems weird, it's because it's intended to be dual to
--   getScreen :: PhysicalScreen -> X (Maybe ScreenId)
-- from XMonad.Actions.PhysicalScreens.
-- See: https://hackage.haskell.org/package/xmonad-contrib-0.13/docs/XMonad-Actions-PhysicalScreens.html
getPhysicalScreen :: ScreenId -> X (Maybe PhysicalScreen)
getPhysicalScreen sid = do
    pscreens <- physicalScreens
    return $ (Just sid) `elemIndex` pscreens >>= \s -> Just (P s)

rofi :: X String
rofi = withWindowSet $ \windowSet -> do
    let sid = W.screen (W.current windowSet)
    pscreen <- getPhysicalScreen sid
    return $ case pscreen of
                Just (P s) -> "rofi -m " ++ (show s)
                otherwise  -> "rofi"

spawnRofi :: String -> X ()
spawnRofi args = do
    cmd <- rofi
    spawn $ cmd ++ " " ++ args

reflectWith :: X () -> X ()
reflectWith swapFn = do
    sendMessage $ Toggle REFLECTX
    swapFn
    sendMessage $ Toggle REFLECTX


--
-- HOOKS
--

startupHook' = do
    spawnOnce "systemctl --user stop graphical-session.target && ~/bin/reset-systemd-environment && systemctl --user start xmonad-session.target"

logHook' = do
    switchTopicHook -- must be first
    historyHook
    workspaceHistoryHook
    refocusLastLogHook
    raiseOverlays

layoutHook' = id
    . onWorkspace "windows" (noBorders Full)
    . mkToggle (single NBFULL)
    . gaps' [((U, 108), False)]
    . avoidStruts
    . tabs
    . mkToggle (single FULL)
    . mkToggle (single REFLECTX)
    . mkToggle (single MIRROR)
    -- Window padding is roughly based on the *text* height of taffybar
    . renamed [CutWordsLeft 1] . spacingWithEdge 7
    . renamed [CutWordsLeft 1] . maximizeWithPadding 14
    -- . onWorkspace "mail" layoutHalfTall
    $ layoutGoldenTall ||| layoutHalfTall
  where
    layoutGoldenTall =
        renamed [Replace "GoldenTall"] $ ResizableTall 1 (3/100) (0.605) []
    layoutHalfTall =
        renamed [Replace "HalfTall"] $ ResizableTall 1 (3/100) (1/2) []
    tabs = id
        . configurableNavigation noNavigateBorders
        . addTabsBottom shrinkText tabTheme
        . subLayout [] Simplest
        . boringWindows
    tabTheme = def
        { fontName            = "xft:sans-serif:size=8"
        , decoHeight          = 16
        , activeBorderWidth   = 0
        , inactiveBorderWidth = 0
        , urgentBorderWidth   = 0
        , activeColor         = "#ab4642"
        , inactiveColor       = "#585858"
        , urgentColor         = "#f7ca88"
        , activeTextColor     = "#282828"
        , inactiveTextColor   = "#282828"
        , urgentTextColor     = "#282828"
        }

manageHook' = composeOne
    [ className =? "ksmserver"                -?> doIgnore
    , className =? "ksmserver-logout-greeter" -?> doIgnore
    , className =? "XLogo"                    -?> doFloat
    , className =? "Firewall-config"          -?> doCenterFloat
    , className =? "systemsettings"           -?> doCenterFloat
    , appName   =? "gp-saml-gui"              -?> doCenterFloat
    , isDesktop                               -?> doWindowAction sendToBottom
    , isDock                                  -?> doWindowAction sendToJustAboveDesktop
    , isTooltip                               -?> doIgnore
    , isFloating                              -?> doCenterFloat
    , isOSD                                   -?> doCenterFloat
    , isDialog                                -?> doFloat
    , transience                              --- move to parent window
    , pure True                               -?> insertPosition Below Newer
    ]

activateHook' = composeOne
    [ className =? "code" -?> doIgnore  -- prevent focus stealing
    , pure True           -?> doFocus
    ]

handleEventHook' =
    refocusLastWhen (return True) <+> lowerPanelOnTimer
  where
    -- Based on https://stackoverflow.com/questions/11045239/can-xmonads-loghook-be-run-at-set-intervals-rather-than-in-merely-response-to/14297833
    lowerPanelOnTimer event = do
        (PanelTimer timerId) <- XS.get
        handleTimer timerId event $ do
            allWindowsByType isDock >>= mapM_ sendToJustAboveDesktop
            return Nothing
        return (All True)

workspaces' = ["web", "ops", "dev", "music", "mail", "chat", "seven", "eight", "nine", "windows"]


--
-- MAIN
--

main = xmonad
    . docks
    . setEwmhActivateHook activateHook'
    . ewmh
    . pagerHints
    . withNavigation2DConfig def { defaultTiledNavigation = centerNavigation }
    $ def
    { modMask            = mod4Mask
    , terminal           = "urxvtc"
    , startupHook        = startupHook'
    , logHook            = logHook'
    , layoutHook         = layoutHook'
    , manageHook         = manageHook'
    , handleEventHook    = handleEventHook'
    , workspaces         = workspaces'
    , borderWidth        = 3
    , focusedBorderColor = "#ab4642"
    , normalBorderColor  = "#585858"
    }
    `additionalKeysP`
    [ ("M-0"           , windows $ W.greedyView "windows")
    , ("M-S-="         , sendMessage $ IncMasterN 1)
    , ("M--"           , sendMessage $ IncMasterN (-1))
    , ("M-'"           , viewScreen def 0)
    , ("M-,"           , viewScreen def 1)
    , ("M-."           , viewScreen def 1)
    , ("M-S-'"         , sendToScreen def 0)
    , ("M-S-,"         , sendToScreen def 1)
    , ("M-S-."         , sendToScreen def 1)
    , ("M-g"           , sendMessage $ ToggleGaps)
    , ("M-f"           , sendMessage $ Toggle NBFULL)
    , ("M-S-f"         , sendMessage $ Toggle FULL)
    , ("M-r"           , sendMessage $ Toggle REFLECTX)
    , ("M-S-r"         , sendMessage $ Toggle MIRROR)
    , ("M-z"           , withFocused $ sendMessage . maximizeRestore)
    , ("M-h"           , windowGo L False)
    , ("M-l"           , windowGo R False)
    , ("M-j"           , windowGo D False)
    , ("M-k"           , windowGo U False)
    , ("M-S-h"         , sendMessage Shrink)
    , ("M-S-l"         , sendMessage Expand)
    , ("M-S-j"         , sendMessage MirrorShrink)
    , ("M-S-k"         , sendMessage MirrorExpand)
    -- Begin tab keybindings
    , ("M-C-h"         , sendMessage $ pullGroup L)
    , ("M-C-l"         , sendMessage $ pullGroup R)
    , ("M-C-j"         , sendMessage $ pullGroup D)
    , ("M-C-k"         , sendMessage $ pullGroup U)
    , ("M-C-m"         , withFocused $ sendMessage . MergeAll)
    , ("M-C-S-m"       , withFocused $ sendMessage . UnMerge)
    , ("M-C-<Tab>"     , onGroup W.focusDown')
    , ("M-C-S-<Tab>"   , onGroup W.focusUp')
    -- End tab keybindings
    , ("M-u"           , windows W.swapUp)
    , ("M-d"           , windows W.swapDown)
    , ("M-x"           , kill)
    , ("M-;"           , nextMatch History (return True))
    , ("M-a"           , toggleWS)
    , ("M-o"           , reflectWith swapPrevScreen)
    , ("M-e"           , reflectWith swapNextScreen)
    , ("M-S-o"         , swapPrevScreen)
    , ("M-S-e"         , swapNextScreen)
    -- , ("M-S-q"         , spawn "qdbus org.kde.ksmserver /KSMServer logout 1 0 1")
    , ("M-S-c"         , spawn "dunstctl close")
    , ("M-S-p"         , spawn "dunstctl history-pop")
    , ("M-S-<Space>"   , spawn "dunstctl context")
    , ("M-s"           , raisePanelTemporarily >> spawn "~/.xmonad/scripts/screensaver toggle")
    -- , ("M-<Escape>"    , unGrab >> spawn "~/.xmonad/scripts/screensaver reset; loginctl lock-session")
    , ("M-<Tab>"       , sendMessage NextLayout)
    , ("M-<Backspace>" , setLayout $ Layout layoutHook')
    , ("M1-<Tab>"      , focusDown)
    , ("M1-S-<Tab>"    , focusUp)
    , ("M-p"           , spawnRofi "-show drun")
    , ("M-w"           , spawnRofi "-show window")
    , ("M1-S-a"        , unGrab >> spawn "xdotool keyup alt+shift && ~/.xmonad/scripts/bw-type jtl/admin 4b70ddc9-0b8a-4479-9691-d330a6b61264")
    , ("M1-S-s"        , unGrab >> spawn "xdotool keyup alt+shift && ~/.xmonad/scripts/bw-type jtl/root 687ad9eb-489e-419c-984a-6dabdbe463b7")
    , ("M1-S-u"        , unGrab >> spawn "xdotool keyup alt+shift && ~/.xmonad/scripts/bw-type UMD 042bbfbc-befc-41d1-8c13-3fc3fd0e289f")
    , ("M-`"           , spawn "~/.xmonad/scripts/toggle-dpms")
    , ("M-<Space>"               , spawn "~/bin/playerctl play-pause")
    , ("<XF86AudioPlay>"         , spawn "~/bin/playerctl play-pause")
    , ("<XF86AudioMicMute>"      , spawn "~/.xmonad/scripts/mic toggle-mute")
    , ("<XF86AudioMute>"         , raisePanelTemporarily >> spawn "~/.xmonad/scripts/volume toggle-mute")
    , ("<XF86AudioLowerVolume>"  , raisePanelTemporarily >> spawn "~/.xmonad/scripts/volume -0.5dB")
    , ("<XF86AudioRaiseVolume>"  , raisePanelTemporarily >> spawn "~/.xmonad/scripts/volume +0.5dB")
    , ("<XF86MonBrightnessDown>" , raisePanelTemporarily >> spawn "~/.xmonad/scripts/brightness decrease")
    , ("<XF86MonBrightnessUp>"   , raisePanelTemporarily >> spawn "~/.xmonad/scripts/brightness increase")
    ]
    `removeKeysP`
    [ "M-S-<Tab>"   -- focus previous window
    , "M-S-/"       -- show help
    ]

-- vim: filetype=haskell
