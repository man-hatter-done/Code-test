/*
 * Proprietary Software License Version 1.0
 *
 * Copyright (C) 2025 BDG
 *
 * Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
 * under the terms of the Proprietary Software License.
 */

#pragma once
#include "common/mach-o.h"
#include "openssl.h"
#include <set>
/**
 * Class for manipulating Mach-O architecture files
 */
class ZArchO {
public:
    /**
     * Default constructor
     */
    ZArchO();
    
    /**
     * Initializes the object with Mach-O binary data
     *
     * @param pBase Pointer to the binary data
     * @param uLength Length of the binary data in bytes
     * @return true if initialization succeeded, false otherwise
     */
    bool Init(uint8_t *pBase, uint32_t uLength);

public:
    /**
     * Signs the Mach-O binary
     *
     * @param pSignAsset Signing assets to use
     * @param bForce Force signing even if already signed
     * @param strBundleId Bundle identifier
     * @param strInfoPlistSHA1 SHA1 hash of the Info.plist file
     * @param strInfoPlistSHA256 SHA256 hash of the Info.plist file
     * @param strCodeResourcesData Code resources data
     * @return true if signing succeeded, false otherwise
     */
    bool Sign(ZSignAsset *pSignAsset, bool bForce, const string &strBundleId, const string &strInfoPlistSHA1,
              const string &strInfoPlistSHA256, const string &strCodeResourcesData);
    
    /**
     * Prints information about the Mach-O binary
     */
    void PrintInfo();
    
    /**
     * Checks if the binary is an executable
     *
     * @return true if executable, false otherwise
     */
    bool IsExecute();
    
    /**
     * Injects a dylib into the binary
     *
     * @param bWeakInject Whether to use weak injection
     * @param szDyLibPath Path to the dylib to inject
     * @param bCreate Reference to a bool that will be set to true if a new command was created
     * @return true if injection succeeded, false otherwise
     */
    bool InjectDyLib(bool bWeakInject, const char *szDyLibPath, bool &bCreate);
    
    /**
     * Reallocates code signing space
     *
     * @param strNewFile Path to the new file
     * @return The size of the reallocated space
     */
    uint32_t ReallocCodeSignSpace(const string &strNewFile);
    
    /**
     * Uninstalls dylibs from the binary
     *
     * @param dylibNames Set of dylib names to uninstall
     */
    void uninstallDylibs(const set<string> &dylibNames);
    
    /**
     * Changes a dylib path in the binary
     *
     * @param oldPath Old dylib path
     * @param newPath New dylib path
     * @return true if change succeeded, false otherwise
     */
    bool ChangeDylibPath(const char *oldPath, const char *newPath);
    
    /**
     * Lists all dylibs used by the binary
     *
     * @return Vector of dylib names
     */
    std::vector<std::string> ListDylibs();

private:
    /**
     * Byte-order swaps a value if needed
     *
     * @param uValue Value to swap
     * @return Byte-swapped value if big-endian, original value if little-endian
     */
    uint32_t BO(uint32_t uValue) const;
    
    /**
     * Gets the file type name for a file type code
     *
     * @param uFileType File type code
     * @return String representation of the file type
     */
    static const char *GetFileType(uint32_t uFileType);
    
    /**
     * Gets architecture name for CPU type and subtype
     *
     * @param cpuType CPU type
     * @param cpuSubType CPU subtype
     * @return String representation of the architecture
     */
    static const char *GetArch(int cpuType, int cpuSubType);
    
    /**
     * Builds code signature for the binary
     *
     * @param pSignAsset Signing assets to use
     * @param bForce Force signing even if already signed
     * @param strBundleId Bundle identifier
     * @param strInfoPlistSHA1 SHA1 hash of the Info.plist file
     * @param strInfoPlistSHA256 SHA256 hash of the Info.plist file
     * @param strCodeResourcesSHA1 SHA1 hash of code resources
     * @param strCodeResourcesSHA256 SHA256 hash of code resources
     * @param strOutput Reference to output string
     * @return true if building succeeded, false otherwise
     */
    bool BuildCodeSignature(ZSignAsset *pSignAsset, bool bForce, const string &strBundleId,
                            const string &strInfoPlistSHA1, const string &strInfoPlistSHA256,
                            const string &strCodeResourcesSHA1, const string &strCodeResourcesSHA256,
                            string &strOutput);

public:
    /** Pointer to the base of the Mach-O binary data */
    uint8_t *m_pBase;
    
    /** Total length of the binary data */
    uint32_t m_uLength;
    
    /** Length of the code section */
    uint32_t m_uCodeLength;
    
    /** Pointer to the signature section base */
    uint8_t *m_pSignBase;
    
    /** Length of the signature section */
    uint32_t m_uSignLength;
    
    /** Contents of the Info.plist file */
    string m_strInfoPlist;
    
    /** Whether the binary is encrypted */
    bool m_bEncrypted;
    
    /** Whether the binary is 64-bit */
    bool m_b64;
    
    /** Whether the binary uses big-endian byte order */
    bool m_bBigEndian;
    
    /** Whether there's enough space for code signing */
    bool m_bEnoughSpace;
    
    /** Pointer to the code signature segment */
    uint8_t *m_pCodeSignSegment;
    
    /** Pointer to the link edit segment */
    uint8_t *m_pLinkEditSegment;
    
    /** Available free space in load commands */
    uint32_t m_uLoadCommandsFreeSpace;
    
    /** Pointer to the Mach-O header */
    mach_header *m_pHeader;
    
    /** Size of the Mach-O header */
    uint32_t m_uHeaderSize;
};
