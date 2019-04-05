module Echidna.Transaction where

    import Prelude hiding (Word)
    
    import Control.Lens
    import Control.Monad (liftM4)
    import Control.Monad.Catch (MonadThrow)
    import Control.Monad.Random.Strict (MonadRandom, getRandomR)
    import Control.Monad.Reader.Class (MonadReader)
    import Control.Monad.State.Strict (MonadState, State, runState)
    import Data.Aeson (ToJSON(..), object)
    import Data.ByteString (ByteString)
    import Data.Either (either, lefts)
    import Data.Has (Has(..))
    import Data.List (intercalate)
    import Data.Set (Set)
    import EVM
    import EVM.ABI (abiCalldata, abiTypeSolidity, abiValueType)
    import EVM.Concrete (Blob(..), Word(..), w256)
    import EVM.Types (Addr)
    
    import qualified Control.Monad.State.Strict as S (state)
    import qualified Data.Set as S
    import qualified Data.Text as T
    import qualified Data.Vector as V
    
    import Echidna.ABI
    import Echidna.Transaction

    data Etheno = Etheno { _event :: !EthenoEvent
                         , _address  :: !Addr
                         , _from  :: !Addr
                         , _to :: !Addr
                         , _contractAddr :: !Addr
                         , _gasUsed :: !Integer
                         , _gasPrice :: !Integer
                         , _data :: !ByteString
                         , _value :: !Word
                         } deriving (Eq, Ord, Show, Generic)

    makeLenses ''Etheno

    instance FromJSON Etheno

    data EthenoEvent = AccountCreated | ContractCreated | FunctionCall

    execEthenoBatch :: (MonadState x m, Has VM x, MonadThrow m) => FilePath -> m VMResult-> m VMResult
    execEthenoBatch fp m = do
        txs <- -- load + parse the etheno file
        forM_ txs $ \tx -> do
            og <- get
            setupEthenoTx tx 
            res <- m
            case (res, tx ^. event == ContractCreated) of
                (Reversion,   _)         -> put og
                (VMFailure x, _)         -> h x -- Need to determine error fn
                (VMSuccess (B bc), True) -> hasLens %= execState ( replaceCodeOfSelf bc
                                                                >> loadContract (tx ^.contractAddr))
                _                        -> pure ()
            return res

    setupEthenoTx :: (MonadState x m, Has VM x) => Tx -> m ()
    setupEthenoTx (Etheno e a f t c _ _ d v) = S.state . runState . zoom hasLens . sequence_ $
        [ result .= Nothing, state . pc .= 0, state . stack .= mempty, state . gas .= 0xffffffff
        , env . origin .= f, state . caller .= f, state . callvalue .= v, setup] where 
        setup case e of 
            AccountCreated -> -- ?
            ContractCreated -> assign (env . contracts . at c) (Just $ initialContract d) >> loadContract r
            FunctionCall -> loadContract t >> state . calldata .= d