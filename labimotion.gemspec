require_relative "lib/labimotion/version"

Gem::Specification.new do |spec|
  spec.name          = 'labimotion'
  spec.version       = Labimotion::VERSION
  spec.summary       = 'Chemotion LabIMotion'
  spec.authors       = ['Chia-Lin Lin', 'Pei-Chi Huang']
  spec.email         = ['chia-lin.lin@kit.edu', 'pei-chi.huang@kit.edu']
  spec.homepage      = 'https://github.com/LabIMotion/labimotion'
  spec.license       = 'AGPL-3.0'
  spec.files         = Dir['lib/**/*.rb', 'labimotion.rb']
  spec.require_paths = ['lib']
  spec.add_dependency "rails", "~> 6.1.7"
end
