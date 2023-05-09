// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/AccountStorage.sol";
import "../authority/Authority.sol";
import "../interfaces/IModuleManager.sol";
import "./PluginManager.sol";
import "../libraries/AddressLinkedList.sol";
import "../libraries/SelectorLinkedList.sol";

abstract contract ModuleManager is IModuleManager, PluginManager {
    using AddressLinkedList for mapping(address => address);
    using SelectorLinkedList for mapping(bytes4 => bytes4);

    address public immutable defaultModuleManager;

    bytes4 internal constant FUNC_ADD_MODULE =
        bytes4(keccak256("addModule(address,bytes4[],bytes)"));
    bytes4 internal constant FUNC_REMOVE_MODULE =
        bytes4(keccak256("removeModule(address)"));

    constructor(address _defaultModuleManager) {
        defaultModuleManager = _defaultModuleManager;
    }

    function modulesMapping()
        private
        view
        returns (mapping(address => address) storage modules)
    {
        modules = AccountStorage.layout().modules;
    }

    function moduleSelectorsMapping()
        private
        view
        returns (
            mapping(address => mapping(bytes4 => bytes4))
                storage moduleSelectors
        )
    {
        moduleSelectors = AccountStorage.layout().moduleSelectors;
    }

    function _isAuthorizedModule(address module) private view returns (bool) {
        if (defaultModuleManager == module) {
            return true;
        }
        return modulesMapping().isExist(module);
    }

    function isAuthorizedSelector(
        address module,
        bytes4 selector
    ) private view returns (bool) {
        if (
            defaultModuleManager == module &&
            (selector == FUNC_ADD_MODULE ||
                selector == FUNC_REMOVE_MODULE ||
                selector == FUNC_ADD_PLUGIN ||
                selector == FUNC_REMOVE_PLUGIN)
        ) {
            return true;
        }
        if (!modulesMapping().isExist(module)) {
            return false;
        }
        mapping(address => mapping(bytes4 => bytes4))
            storage moduleSelectors = moduleSelectorsMapping();
        return moduleSelectors[module].isExist(selector);
    }

    function isAuthorizedModule(
        address module
    ) external override returns (bool) {
        return _isAuthorizedModule(module);
    }

    function addModule(Module memory aModule) internal {
        require(aModule.selectors.length > 0, "selectors empty");
        address module = address(aModule.module);

        mapping(address => address) storage modules = modulesMapping();
        modules.add(module);
        mapping(address => mapping(bytes4 => bytes4))
            storage moduleSelectors = moduleSelectorsMapping();
        moduleSelectors[module].add(aModule.selectors);

        aModule.module.walletInit(aModule.initData);

        emit ModuleAdded(module, aModule.selectors);
    }

    function removeModule(address module) internal {
        mapping(address => address) storage modules = modulesMapping();
        modules.remove(module);

        mapping(address => mapping(bytes4 => bytes4))
            storage moduleSelectors = moduleSelectorsMapping();
        moduleSelectors[module].clear();

        try IModule(module).walletDeInit() {
            emit ModuleRemoved(module);
        } catch {
            emit ModuleRemovedWithError(module);
        }
    }

    function listModule()
        external
        view
        override
        returns (address[] memory modules, bytes4[][] memory selectors)
    {
        mapping(address => address) storage _modules = modulesMapping();
        modules = _modules.list(
            AddressLinkedList.SENTINEL_ADDRESS,
            type(uint8).max
        );

        mapping(address => mapping(bytes4 => bytes4))
            storage moduleSelectors = moduleSelectorsMapping();

        for (uint256 i = 0; i < modules.length; i++) {
            selectors[i] = moduleSelectors[modules[i]].list(
                SelectorLinkedList.SENTINEL_SELECTOR,
                type(uint8).max
            );
        }
    }

    function execFromModule(bytes calldata data) external override {
        // get 4bytes
        bytes4 selector = bytes4(data[0:4]);
        require(
            isAuthorizedSelector(msg.sender, selector),
            "unauthorized module selector"
        );

        if (selector == FUNC_ADD_MODULE) {
            // addModule(address,bytes4[],bytes)
            Module memory _module = abi.decode(data[4:], (Module));
            addModule(_module);
        } else if (selector == FUNC_REMOVE_MODULE) {
            // removeModule(address)
            address module = abi.decode(data[4:], (address));
            removeModule(module);
        } else if (selector == FUNC_ADD_PLUGIN) {
            // addPlugin(address,bytes)
            Plugin memory _plugin = abi.decode(data[4:], (Plugin));
            addPlugin(_plugin);
        } else if (selector == FUNC_REMOVE_PLUGIN) {
            // removePlugin(address)
            address plugin = abi.decode(data[4:], (address));
            removePlugin(plugin);
        } else {
            CallHelper.callWithoutReturnData(
                CallHelper.CallType.Call,
                address(this),
                data
            );
        }
    }
}