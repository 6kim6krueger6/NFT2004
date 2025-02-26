-include .env

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

test :; forge test 

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast
SEPOLIA_NETWORK_ARGS := --rpc-url ${SEPOLIA_RPC_URL} --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
ARBITRUM_NETWORK_ARGS := --rpc-url ${ARBITRUM_SEPOLIA_RPC_URL} --private-key $(PRIVATE_KEY) --broadcast --verify --verifier-url https://api-sepolia.arbiscan.io/api --verifier etherscan --etherscan-api-key $(ARBITRUM_SEPOLIA_API_KEY) -vvvv
MONAD_NETWORK_ARGS := --rpc-url ${MONAD_RPC_URL} --private-key $(PRIVATE_KEY) --broadcast --verify --verifier-url https://sourcify-api-monad.blockvision.org --verifier sourcify --chain 10143
deploy-anvil:
	@forge script script/NFTdeploy.s.sol:NFTdeploy $(NETWORK_ARGS)

deploy-sepolia:
	@forge script script/NFTdeploy.s.sol:NFTdeploy $(SEPOLIA_NETWORK_ARGS)

deploy-arbitrum:
	@forge script script/NFTdeploy.s.sol:NFTdeploy $(ARBITRUM_NETWORK_ARGS)

deploy-monad:
	@forge script script/NFTdeploy.s.sol:NFTdeploy $(MONAD_NETWORK_ARGS)