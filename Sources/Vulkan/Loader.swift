import CVulkan
#if os(Linux)
    import Glibc
#elseif os(Windows)
    import WinSDK
#else
    import Darwin
#endif


public protocol Loader {
    var vkGetInstanceProcAddr: PFN_vkGetInstanceProcAddr { get }
}

public enum LoaderError: Error {
    case loaderNotFound
    case symbolNotFound
}

public class DynamicLoader: Loader {
    #if os(Windows)
        let handle: HMODULE
    #else
        let handle: UnsafeMutableRawPointer
    #endif
    public let vkGetInstanceProcAddr: PFN_vkGetInstanceProcAddr

    public init(path: String) throws {
        #if os(Windows)
            let loadedhandle = path.withCString(encodedAs: UTF16.self) { LoadLibraryW($0) }
            guard let handle = loadedhandle else { throw LoaderError.loaderNotFound }
            guard let vkGetInstanceProcAddr = GetProcAddress(handle, "vkGetInstanceProcAddr") else {
                FreeLibrary(handle)
                throw LoaderError.symbolNotFound
            }
        #else
            guard let handle = dlopen(path, RTLD_LAZY) else {
                throw LoaderError.loaderNotFound
            }
            guard let vkGetInstanceProcAddr = dlsym(handle, "vkGetInstanceProcAddr") else {
                dlclose(handle)
                throw LoaderError.symbolNotFound
            }
        #endif
        self.handle = handle
        self.vkGetInstanceProcAddr = unsafeBitCast(vkGetInstanceProcAddr, to: PFN_vkGetInstanceProcAddr.self)
    }

    public convenience init() throws {
        #if os(Linux)
            try self.init(path: "libvulkan.so.1")
        #elseif os(Windows)
            try self.init(path: "vulkan-1.dll")
        #else
            try self.init(path: "libvulkan.1.dylib")
        #endif
    }

    deinit {
        #if os(Windows)
            FreeLibrary(handle)
        #else
            dlclose(handle)
        #endif
    }
}

extension Entry {
    public convenience init() throws {
        self.init(loader: try DynamicLoader())
    }
}
