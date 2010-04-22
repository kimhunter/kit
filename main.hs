module Main where
  import qualified Data.ByteString as BS

  import Text.JSON
  import Kit.XCode.Builder
  import Kit.Verify
  import System.Environment
  import System.Directory
  import System.FilePath.Posix
  import Kit.Repository
  import Kit.Kit
  import Kit.Spec
  import Kit.Package
  import Kit.Project
  import Kit.Util    
  import Data.List
  import Control.Monad.Trans
  import Data.Monoid
  import qualified Data.Traversable as T
  
  defaultLocalRepoPath = do
      home <- getHomeDirectory
      return $ home </> ".kit" </> "repository"
  defaultLocalRepository = fmap fileRepo defaultLocalRepoPath
        
  -- given a kit spec, 
  -- download all kits (and deps)
  -- extract all kits to directories
  -- manage KitProject
  
  handleFails (Left e) = do
    print e
    return ()
  handleFails (Right _) = return ()
  
  me :: IO ()
  me = do
        r <- unKitIO g
        handleFails r
    where g = do
          repo <- liftIO defaultLocalRepository
          deps <- getMyDeps repo
          puts $ "Dependencies: " ++ (stringJoin ", " $ map kitFileName deps)
          liftIO $ mapM (installKit repo) deps
          puts " -> Generating XCode project..."
          liftIO $ generateXCodeProject $ deps |> kitFileName
          liftIO $ generateXCodeConfig $ deps |> kitFileName
          puts "Kit complete."
            where p x = liftIO $ print x
                  puts x = liftIO $ putStrLn x
  
  packageKit :: IO ()
  packageKit = do
      mySpec <- unKitIO myKitSpec
      T.for mySpec package
      return ()
  
  deployLocal :: IO ()
  deployLocal = do
    mySpec <- unKitIO myKitSpec
    T.for mySpec package
    T.for mySpec x
    return ()
      where
        x :: KitSpec -> IO ()
        x spec = let 
              k = specKit spec
              kf = kitFileName . specKit $ spec
              pkg = (kf ++ ".tar.gz")
            in do
              repo <- defaultLocalRepoPath
              let thisKitDir = repo </> "kits" </> kitName k </> kitVersion k
              createDirectoryIfMissing True thisKitDir
              copyFile pkg $ thisKitDir </> pkg
              copyFile "KitSpec" $ thisKitDir </> "KitSpec"
  
  verify :: KitIO ()
  verify = do
      mySpec <- myKitSpec
      puts "Checking that the kit can be depended upon..."
      puts " #> Deploying locally"
      liftIO deployLocal
      puts " #> Building temporary parent project"
      tmp <- liftIO getTemporaryDirectory
      liftIO $ inDirectory tmp $ do
        let kitVerifyDir = "kit-verify"
        cleanOrCreate kitVerifyDir
        inDirectory kitVerifyDir $ do
          writeFile "KitSpec" $ encode (KitSpec (Kit "verify-kit" "1.0") [specKit mySpec])
          me
          getCurrentDirectory >>= putStrLn
        putStrLn "OK."
      puts "End checks."
    where
      puts = liftIO . putStrLn
  
  handleArgs :: [String] -> IO ()
  handleArgs ["me"] = me
  handleArgs ["package"] = packageKit
  handleArgs ["deploy-local"] = deployLocal
  handleArgs ["verify"] = unKitIO verify >>= handleFails
  handleArgs ["create-spec", name, version] = do
    let kit =(Kit name version)
    let spec = KitSpec kit []
    putStrLn $ "Kit create: " ++ kitFileName kit
    writeFile "KitSpec" $ encode spec
    return ()
    
  handleArgs _ = putStrLn "Usage: TODO"
    
  main :: IO ()
  main = do
      localRepo <- defaultLocalRepository
      path <- defaultLocalRepoPath
      createDirectoryIfMissing True path
      args <- getArgs
      handleArgs args

      
          
  