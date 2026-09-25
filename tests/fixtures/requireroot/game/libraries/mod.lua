-- Fixture module for the require-shim tests: counts how often it is executed.
__requireModLoads = (__requireModLoads or 0) + 1
return { name = "mod", loads = __requireModLoads }
