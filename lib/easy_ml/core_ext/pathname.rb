require "pathname"

module EasyML
  module CoreExt
    module Pathname
      def append(folder)
        dir = cleanpath
        dir = dir.join(folder) unless basename.to_s == folder
        dir
      end
    end
  end
end

Pathname.include EasyML::CoreExt::Pathname
