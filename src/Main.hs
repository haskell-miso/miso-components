-----------------------------------------------------------------------------
{-# LANGUAGE CPP                #-}
{-# LANGUAGE LambdaCase         #-}
{-# LANGUAGE DeriveGeneric      #-}
{-# LANGUAGE DeriveAnyClass     #-}
{-# LANGUAGE TypeApplications   #-}
{-# LANGUAGE OverloadedStrings  #-}
-----------------------------------------------------------------------------
module Main where
-----------------------------------------------------------------------------
import           GHC.Generics
import           Data.Aeson
-----------------------------------------------------------------------------
import           Miso
import           Miso.String
import           Miso.Lens
-----------------------------------------------------------------------------
#ifdef WASM
foreign export javascript "hs_start" main :: IO ()
#endif
-----------------------------------------------------------------------------
data Action
  = AddOne
  | SubtractOne
  | Mount ComponentId
  | Subscribe
  | Unsubscribe
  | Welcomed
  | Oops
  | Failure MisoString
  | GetComponentId Int
  | Notification Message
  | Init
-----------------------------------------------------------------------------
data Message
  = Increment
  | Decrement
  deriving (Show, Eq, Generic, ToJSON, FromJSON)
-----------------------------------------------------------------------------
main :: IO ()
main = run $ startComponent $ server { initialAction = Just Init }
-----------------------------------------------------------------------------
arithmetic :: Topic Message
arithmetic = topic "arithmetic"
-----------------------------------------------------------------------------
type ParentModel = ()
-----------------------------------------------------------------------------
-- | Demonstrates a simple server / client, pub / sub setup for 'Component'
-- In this contrived example, the server component holds the
-- incrementing / decrementing actions, and relays them to the clients
-- via the pub / sub mechanism.
--
-- Notice the server has no 'model' (e.g. `()`)
--
server :: App ParentModel Action
server = component () update_ $ \() ->
  div_
  []
  [ "Server component"
  , button_ [ onClick AddOne ] [ "+" ]
  , button_ [ onClick SubtractOne ] [ "-" ]
  , p_ [ onMountedWith Mount ] +> client_ "client 1"
  , p_ [ onMountedWith Mount ] +> client_ "client 2"
  ] where
      update_ :: Action -> Transition ParentModel Action
      update_ = \case
        Init -> do
          io_ $ consoleLog ("parent subscribing")
          subscribe arithmetic Notification Failure
        Notification Increment ->
          io_ (consoleLog "parent got increment")
        Notification Decrement ->
          io_ (consoleLog "parent got decrement")
        Failure msg ->
          io_ $ consoleError ("Decode failure: " <> ms msg)
        AddOne ->
          publish arithmetic Increment
        SubtractOne ->
          publish arithmetic Decrement
        Mount childId ->
          mail @MisoString childId "welcome"
        _ -> pure ()
-----------------------------------------------------------------------------
client_ :: MisoString -> Component ParentModel Int Action
client_ name = (clientComponent name)
  { initialAction = Just Subscribe
  , mailbox = receiveMail
  }
-----------------------------------------------------------------------------
receiveMail :: Value -> Maybe Action
receiveMail (String "welcome") = Just Welcomed
receiveMail _ = Just Oops
-----------------------------------------------------------------------------
clientComponent :: MisoString -> Component () Int Action
clientComponent name = component 0 update_ $ \m ->
  div_
  []
  [ br_ []
  , text (name <> " : " <> ms (m ^. _id))
  , button_ [ onClick Unsubscribe ] [ "unsubscribe" ]
  , button_ [ onClick Subscribe ] [ "subscribe" ]
  ] where
      update_ :: Action -> Effect () Int Action
      update_ = \case
        AddOne -> do
          _id += 1
        SubtractOne ->
          _id -= 1
        Unsubscribe ->
          unsubscribe arithmetic
        Subscribe ->
          subscribe arithmetic Notification Failure
        Notification Increment ->
          update_ AddOne
        Notification Decrement ->
          update_ SubtractOne
        Failure msg ->
          io_ $ consoleError ("Decode failure: " <> ms msg)
        Welcomed ->
          io_ (consoleLog "I was just welcomed by my parent")
        Oops ->
          io_ (consoleLog "oops, bad mail decoding")
        _ ->
          pure ()
-----------------------------------------------------------------------------
