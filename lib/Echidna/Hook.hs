{-# LANGUAGE TemplateHaskell #-}

module Echidna.Hook where

import Control.Lens
import Data.Text (Text)

data HookConf = HookConf { _after_init  :: [Text]
                         , _before_each :: [Text]
                         , _after_each  :: [Text]
                         }
  deriving (Show, Eq)

makeLenses ''HookConf
