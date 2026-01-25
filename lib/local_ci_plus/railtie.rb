# frozen_string_literal: true

require "rails/railtie"

module LocalCiPlus
  class Railtie < Rails::Railtie
    generators do
      require_relative "generators/install_generator"
      require_relative "generators/update_generator"
    end
  end
end
