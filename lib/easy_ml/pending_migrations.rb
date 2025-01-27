module EasyML
  def self.pending_migrations?
    return false unless defined?(ActiveRecord)

    # Get all migration files from our templates
    template_dir = File.expand_path("../railtie/generators/templates/migration", __dir__)
    template_migrations = Dir.glob(File.join(template_dir, "*.tt")).map do |f|
      File.basename(f, ".tt").sub(/^create_/, "")
    end

    # Get all existing migrations
    existing_migrations = Dir.glob(Rails.root.join("db/migrate/*_*.rb")).map do |f|
      File.basename(f).sub(/^\d+_create_/, "").sub(/\.rb$/, "")
    end

    # Check if any template migrations are not in existing migrations
    (template_migrations - existing_migrations).any?
  end
end
