Gem::Specification.new do |s|
  s.name        = 'parallelizer'
  s.version     = '0.0.5'
  s.date        = '2014-02-28'
  s.summary     = "Run commands in parallel in JRuby, on a reusable thread pool"
  s.description = "Run commands in parallel in JRuby, on a reusable thread pool"
  s.authors     = ["Mohamed Hafez"]
  s.files       = ["lib/parallelizer.rb", "lib/parallelizer/org.rubygems.parallelizer.jar"]
  s.homepage    = 'https://github.com/mohamedhafez/parallelizer'
  s.platform    = 'java'
  s.license     = 'MIT'
end
