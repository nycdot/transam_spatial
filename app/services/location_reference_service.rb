#-------------------------------------------------------------------------------
#
# Location Reference Service
#
# Centralizes all the logic for encoding, checking, and parsing location
# references within TransAM. This method is mainly used for assets and other classes
# that implement TransamGeoLocatble
#
# A location reference can be any format that is supported by the geocoder that
# is configured. The standard formats that are supported by *all* geocoders are
#
#     address
#     coordinate
#     derived
#     well_known_text
#
# All geocoder services need to implement the parse_xxxx method for each non-standard
# LRS format, for example if there were a ROUTE_MILEPOINT LRS type the geocoder
# would need to implement parse_route_milepoint() and parse_address() to parse an
# address string
#
# If the geocode was sucessful the location reference service stores the following:
#
#     formatted_location_reference -- a canonical version of the location reference
#                                     returned by the geocoder. If the geocoder does
#                                     re-format, this is the same as the input location
#                                     reference
#     coords                       -- An array of coordinate pairs in the format
#                                     [[x1, y1],[x2,y2],...,[xn,yn]]
#     warnings                     -- An array of warning messages returned by the
#                                     geocoder
#
# If GEOCODING_SERVICE supports nodes, then the service will also store:
#
#     from_node -- id of an intersection node, or the first node in a cross street list,
#                  or the last FromId in a block face list.
#     to_node   -- empty an intersection, or the last node in a cross street list,
#                  or the last ToId in a block face list.
#
# If the geocode failed, error messages will be returned in the errors array
#
#-------------------------------------------------------------------------------
class LocationReferenceService

  # The geocoder to use comes from the Rails config
  GEOCODING_SERVICE = Rails.application.config.geocoding_service

  #-----------------------------------------------------------------------------
  # Inputs
  #-----------------------------------------------------------------------------
  # the raw (input) location reference
  attr_accessor :location_reference
  # the format used to interpret the location reference
  attr_accessor :format

  #-----------------------------------------------------------------------------
  # Outputs
  #-----------------------------------------------------------------------------
  # the coordinates returned, if any
  attr_reader   :coords
  # the standardized/formatted location reference
  attr_reader   :formatted_location_reference
  # an array of errors generated by this service or by the geocoder
  attr_accessor :errors
  # an array of warnings from the geocoder service
  attr_accessor :warnings
  # from and to node ids if supported by the geocoder service
  attr_reader :from_node
  attr_reader :to_node
  
  #-----------------------------------------------------------------------------
  # Configurations
  #-----------------------------------------------------------------------------
  # the Geocoding service used to geocode the location references
  attr_reader   :geocoding_service

  #-----------------------------------------------------------------------------

  #-----------------------------------------------------------------------------
  # Returns true if the parser has errors
  def has_errors?
    @errors.present?
  end

  #-----------------------------------------------------------------------------
  # Parses a location reference. This method simply delegates the processing to
  # the geocoder that has been configured. The method called is constructed from
  # the location reference type (format). If the method is not supported by the
  # geocoder, an error is generated
  def parse(locref, format)
    Rails.logger.debug "parse '#{locref}', format = '#{format}'"
    # reset the current state
    reset
    @location_reference = locref
    @format = format

    # the method signature defaults to parse_xxx where xxx is the name of the
    # LRS format.
    parse_method = "parse_#{format.downcase}"
    if @geocoding_service.respond_to? parse_method
      method_object = @geocoding_service.method parse_method
      method_object.call @location_reference

      # process the results. If errors were generated then we add them to this
      # list of errors
      if @geocoding_service.has_errors?
        @geocoding_service.errors.each do |e|
          @errors << e
        end
      else
        # propagate any warnings from the service to this instance
        @geocoding_service.warnings.each {|x| @warnings << x}
        # get the coordinates from the geocoder if any are present
        @coords = @geocoding_service.coords
        # cache the canoical representation of the address, if one is provided
        @formatted_location_reference = @geocoding_service.formatted_location_reference
        @from_node = @geocoding_service.try(:from_node)
        @to_node = @geocoding_service.try(:to_node)
      end
    else
      @errors << "Geocoder method #{parse_method} is not supported for geocoding service #{GEOCODING_SERVICE}"
    end

    @errors.empty?
  end
  #-----------------------------------------------------------------------------
  # Initialize, a hash of options can be added in
  def initialize(attrs = {})
    # reset the current state
    reset

    attrs.each do |k, v|
      self.send "#{k}=", v
    end

    # initialize the geocoding service based on the Rails config
    @geocoding_service = GEOCODING_SERVICE.constantize.new

  end


  #-----------------------------------------------------------------------------
  protected
  #-----------------------------------------------------------------------------

  def reset
    @formatted_location_reference = nil
    @coords = []
    @errors = []
    @warnings = []
    @from_node = nil
    @to_node = nil
  end

end
