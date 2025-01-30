module EasyML
  class PreprocessingStep < ActiveRecord::Base
    self.table_name = "easy_ml_preprocessing_steps"

    scope :training, -> { where(type: :training) }
    scope :inference, -> { where(type: :inference) }

    VALID_TYPES = %w[training inference].freeze
    VALID_METHODS = %w[none categorical most_frequent mean median ffill constant].freeze
    NUMERIC_METHODS = %w[mean median constant].freeze
    
    REQUIRED_PARAMS = {
      'categorical' => {
        categorical_min: 100,
        one_hot: true,
        ordinal_encoding: false
      }
    }.freeze

    OPTIONAL_PARAMS = {
      'mean' => [:clip],
      'median' => [:clip],
      'constant' => [:clip]
    }.freeze

    validates :type, inclusion: { in: VALID_TYPES }
    validates :type, uniqueness: { scope: :column_id, message: 'already has a preprocessing step of this type' }
    belongs_to :column, class_name: 'EasyML::Column'
    
    validates :method, presence: true, inclusion: { in: VALID_METHODS }
    validate :validate_params_structure
    
    before_validation :apply_defaults
    
    def params
      super&.symbolize_keys || {}
    end

    def numeric?
      NUMERIC_METHODS.include?(method)
    end

    def categorical?
      method == 'categorical'
    end

    def one_hot?
      params[:one_hot] == true
    end

    def ordinal_encoding?
      params[:ordinal_encoding] == true
    end

    def encoding
      if categorical? 
        one_hot? ? :one_hot : :ordinal_encoding
      else
        nil
      end
    end

    def allowed_categories
      return nil unless one_hot?

      begin
        column.dataset.preprocessor.statistics.dup.to_h.dig(column.name.to_sym, :allowed_categories).sort.concat(["other"])
      rescue => e
        binding.pry
      end
    end

    private

    def validate_params_structure
      # Ensure params are empty for methods that don't accept params
      if method == 'none' || !REQUIRED_PARAMS.key?(method) && !OPTIONAL_PARAMS.key?(method)
        if params.present?
          errors.add(:params, "#{method} method does not accept any parameters")
          self.params = {}
        end
        return
      end

      # For methods with required params, ensure they're present
      if REQUIRED_PARAMS.key?(method)
        missing_params = REQUIRED_PARAMS[method].keys - params.keys
        if missing_params.any?
          errors.add(:params, "Missing required parameters: #{missing_params.join(', ')}")
        end
      end

      # For methods with optional params, ensure only valid params are present
      if OPTIONAL_PARAMS.key?(method)
        invalid_params = params.keys - OPTIONAL_PARAMS[method]
        if invalid_params.any?
          errors.add(:params, "Invalid parameters: #{invalid_params.join(', ')}")
        end
      end

      validate_categorical_params if categorical?
      validate_numeric_params if numeric?
    end

    def validate_categorical_params
      if params[:one_hot] && params[:ordinal_encoding]
        errors.add(:params, "Cannot use both one_hot and ordinal_encoding simultaneously")
      end

      unless params[:one_hot] || params[:ordinal_encoding]
        errors.add(:params, "Must specify either one_hot or ordinal_encoding for categorical preprocessing")
      end

      if (min = params[:categorical_min])
        unless min.is_a?(Integer) && min > 0
          errors.add(:params, "categorical_min must be a positive integer")
        end
      end
    end

    def validate_numeric_params
      return unless params.key?(:clip)

      unless params[:clip].is_a?(Hash)
        errors.add(:params, "Clip parameter must be a hash with min and max values")
        return
      end

      clip = params[:clip]
      unless clip[:min].is_a?(Numeric) && clip[:max].is_a?(Numeric)
        errors.add(:params, "Clip min and max must be numeric values")
        return
      end

      if clip[:min] >= clip[:max]
        errors.add(:params, "Clip min must be less than max")
      end
    end

    def apply_defaults
      return if method.blank?
      
      case method
      when 'categorical'
        # Always apply all required params with defaults
        self.params = REQUIRED_PARAMS['categorical'].merge(params.symbolize_keys)
      when *NUMERIC_METHODS
        # Only apply clip defaults if clip is present
        if params[:clip]
          self.params = {
            clip: {
              min: 0,
              max: 1_000_000
            }.merge(params[:clip])
          }
        end
      else
        # For methods that don't accept params, ensure params is empty
        self.params = {} unless REQUIRED_PARAMS.key?(method) || OPTIONAL_PARAMS.key?(method)
      end
    end
  end
end