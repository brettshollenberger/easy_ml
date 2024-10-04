require "pathname"

class Pathname
  def append(folder)
    dir = cleanpath
    dir = dir.join(folder) unless basename.to_s == folder
    dir
  end
end
