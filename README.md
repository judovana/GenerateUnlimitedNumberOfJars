# GenerateUnlimitedNumberOfJars
Utility script to generate applicion consiting of thousands of jars to test icedtea-web/javaws performance

Reults on 2000 jars big application
 * java have it read in 3s unsigned, 6s signed
 * for javaws signing have  no overhead

ITW 1.7:
 * Uncached took: 548s
 * Cached took: 303s
 * Offline took: 202s
 * Uncached-signed took: 535s
 * Cached-signed took: 293s
 * Offline-signed took: 197s

ITW 1.8
 * Uncached took: 573s
 * Cached took: 326s
 * Offline took: 210s

ITW 2.0:
 * Uncached took: 191s
 * Cached took: 108s
 * Offline took: 77s
 * Uncached-signed took: 180s
 * Cached-signed took: 100s
 * Offline-signed took: 70s

ITW 1.8.0 with akaschenko's  thread grouping patch
 * Uncached took: 211s
 * Cached took: 109s
 * Offline took: 141s
 * Uncached-signed took: 193s
 * Cached-signed took: 102s
 * Offline-signed took: 134s

