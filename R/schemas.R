# The response schemas of the v1 API, one named character vector each:
# field name = type. The types are
#
#   chr num int int64 lgl dttm date   scalars (int64 is kept as a double);
#   json                               free-form JSON, kept as parsed lists;
#   <Schema>                           a nested object of another schema;
#   <type>[]                           an array (of strings, a character
#                                      vector; of objects, a tibble);
#
# and a trailing "!" marks a field the schema requires (it may still be null).
# tests/testthat/test-spec-drift.R checks every name and requirement here
# against the pinned spec/openapi/v1/openapi.yaml, so this table cannot drift
# from the contract. Enumerations are plain strings: a value added to the API
# later comes through as it is, never as an error.

schemas <- list(
  ActiveAlert = c(
    id = "chr!", event = "chr!", severity = "chr!", urgency = "chr!", certainty = "chr!",
    headline = "chr!", onset = "dttm", expires = "dttm!", ends = "dttm"
  ),
  LocationRef = c(
    slug = "chr!", state = "chr!", name = "chr!", lat = "num!", lon = "num!",
    elevation_m = "num!", type = "chr!", timezone = "chr!"
  ),
  CurrentResponse = c(
    location = "LocationRef!", alerts = "ActiveAlert[]!", alerts_as_of = "dttm!",
    sensor_count = "int!", sensors = "SensorObservation[]!", current = "CurrentConditions!",
    as_of = "dttm!", model_run_initialized_at = "dttm!", nowcast_hours = "TimeSeriesPoint[]",
    units = "chr!", attribution = "ResponseAttribution!", nowcast_unavailable = "chr[]"
  ),
  AlertsResponse = c(
    location = "LocationRef!", alert_count = "int!", as_of = "dttm!",
    alerts = "ActiveAlert[]!", attribution = "ResponseAttribution!"
  ),
  SearchLocationsResponse = c(items = "SearchHit[]!", count = "int!"),
  PublicCatalogLocationPage = c(items = "PublicCatalogLocation[]!", next_cursor = "chr!"),
  PublicCatalogStationPage = c(items = "PublicCatalogStation[]!", next_cursor = "chr!"),
  RunsResponse = c(
    served = "RunsServed!", runs = "RunEntry[]!", count = "int!", next_cursor = "chr!"
  ),
  RunsServed = c(initialized_at = "dttm!", models = "ModelEntry[]!"),
  RunEntry = c(initialized_at = "dttm!"),
  NearbyPointResponse = c(
    lat = "num!", lon = "num!", radius_km = "num!", count = "int!",
    locations = "NearbyLocation[]!"
  ),
  LocationsResponse = c(
    state = "chr!", count = "int!", locations = "LocationSummary[]!", next_cursor = "chr!"
  ),
  NearbyLocationsResponse = c(
    location = "LocationSummary!", radius_km = "num!", count = "int!",
    locations = "NearbyLocation[]!"
  ),
  LocationSummary = c(
    slug = "chr!", state = "chr!", name = "chr!", lat = "num!", lon = "num!",
    elevation_m = "num!", type = "chr!", timezone = "chr!", county = "chr!",
    description = "chr", elevations = "LocationElevation[]"
  ),
  LocationElevation = c(name = "chr!", elevation = "num!", default = "lgl"),
  NearbyLocation = c(
    slug = "chr!", state = "chr!", name = "chr!", lat = "num!", lon = "num!",
    elevation_m = "num!", type = "chr!", timezone = "chr!", county = "chr!",
    description = "chr", elevations = "LocationElevation[]", distance_km = "num!"
  ),
  ProbabilityResult = c(
    term = "chr!", variable = "chr!", op = "chr!", threshold = "num!",
    window_start_hours = "int!", window_end_hours = "int!", aggregation = "chr!",
    from = "dttm!", to = "dttm!", probability = "num!", members = "int!", null_reason = "chr!"
  ),
  WindowTotal = c(
    term = "chr!", variable = "chr!", window_start_hours = "int!", window_end_hours = "int!",
    aggregation = "chr!", from = "dttm!", to = "dttm!", quantiles = "Quantiles!",
    members = "int!", null_reason = "chr!"
  ),
  Quantiles = c(
    mean = "num!", p10 = "num!", p25 = "num!", p50 = "num!", p75 = "num!", p90 = "num!",
    min = "num!", max = "num!", probability = "num"
  ),
  NearestLocation = c(slug = "chr!", url = "chr!", distance_km = "num!", elevation_m = "num!"),
  PrecipDisplay = c(kind = "chr!", chance = "num!", amount = "num"),
  ProbabilityThresholds = c(
    hourly_precipitation = "num!", hourly_snowfall = "num!",
    daily_precipitation_probability = "num!", daily_precipitation_occurrence_probability = "num!",
    daily_snow_probability = "num!"
  ),
  AppliedOptions = c(max_hours = "int!", max_days = "int!", clamped = "chr[]!"),
  ForecastResponse = c(
    thresholds = "ProbabilityThresholds", probabilities = "ProbabilityResult[]",
    window_totals = "WindowTotal[]", applied = "AppliedOptions", location = "LocationRef!",
    model_run = "ModelRunInfo!", units = "chr!", forecast = "ForecastData!",
    elevation_forecasts = "ElevationForecast[]", nowcast_applied = "lgl!",
    nowcast_unavailable = "chr[]", members_view = "chr", gap_flow = "GapFlow",
    nearest_sensors = "NearestSensor[]", point = "PointInfo", current = "CurrentConditions",
    attribution = "ResponseAttribution!"
  ),
  GapFlow = c(
    status = "chr!", pressure_diff_hpa = "num!", wind_multiplier = "num!", direction = "chr!"
  ),
  ResponseAttribution = c(sources = "chr[]!", credit = "chr!", url = "chr!"),
  AttributionRegistry = c(providers = "AttributionProvider[]!"),
  AttributionProvider = c(
    id = "chr!", name = "chr!", credit = "chr!", licence = "chr!", licence_url = "chr!",
    terms_url = "chr!", modified = "lgl!", notices = "chr[]!", sources = "AttributionSource[]!"
  ),
  AttributionSource = c(id = "chr!", name = "chr!", kind = "chr!", provider = "chr!"),
  SensorObservation = c(
    station_id = "chr!", name = "chr!", source = "chr!", observation_time = "dttm!",
    temperature = "num", dewpoint = "num", relative_humidity = "num", wind_speed = "num",
    wind_gust = "num", wind_direction = "num", pressure = "num", precipitation = "num",
    precipitation_rate = "num", reflectivity = "num", pavement_temp = "num", subsurface_temp = "num",
    visibility = "num", cloud_cover = "num", ceiling_height = "num", snow_depth = "num",
    swe = "num", swe_percent_of_median = "num", snowfall = "num", solar_radiation = "num",
    pavement_condition = "chr"
  ),
  CurrentConditions = c(
    time = "dttm!", temperature = "num!", feels_like = "num", condition = "chr!",
    condition_text = "chr!", condition_icon = "chr!", wind_speed = "num!", wind_gust = "num",
    wind_direction = "num!", relative_humidity = "num", dewpoint = "num",
    precipitation_probability = "num", source = "chr!", station = "CurrentStation"
  ),
  CurrentStation = c(station_id = "chr!", name = "chr!", observation_time = "dttm!"),
  PointInfo = c(
    requested_lat = "num!", requested_lon = "num!", lat = "num!", lon = "num!",
    resolution_deg = "num!", elevation = "num!", elevation_source = "chr!", state = "chr!"
  ),
  NearestSensor = c(
    station_id = "chr!", name = "chr!", source = "chr!", distance_km = "num!",
    elevation_diff = "num!", effective_distance_km = "num!", observation_time = "dttm!"
  ),
  ModelRunInfo = c(initialized_at = "dttm!", total_members = "int!", models = "ModelEntry[]!"),
  ModelEntry = c(id = "chr!", cycle = "dttm", members = "int"),
  ForecastData = c(
    max_hours = "int!", interval_hours = "int!", timeseries = "TimeSeriesPoint[]",
    daily = "DailyForecast[]", snow_outlook = "SnowOutlook"
  ),
  SnowOutlook = c(
    next_24h = "num!", next_48h = "num!", next_7d = "num!", overnight_4pm_9am = "num",
    quantiles = "SnowOutlookQuantiles"
  ),
  SnowOutlookQuantiles = c(
    next_24h = "Quantiles!", next_48h = "Quantiles!", next_7d = "Quantiles!"
  ),
  TimeSeriesPoint = c(
    valid_time = "dttm!", lead_time_hours = "int!", is_night = "lgl!", condition = "chr!",
    condition_text = "chr!", condition_icon = "chr!", gust_notable = "lgl",
    precipitation_type = "PrecipType", inversion = "InversionInfo", freezing_level = "FreezingLevel",
    ensemble = "EnsembleStats!", provenance = "HourProvenance", model_means = "ModelMeansEntry[]",
    members = "ModelMembers[]", members_cumulative = "MembersCumulative",
    cumulative_precipitation = "num", cumulative_snowfall = "num"
  ),
  ModelMembers = c(id = "chr!", members = "MemberForecast[]!"),
  ModelMeansEntry = c(
    id = "chr!", temperature = "Quantiles", dewpoint = "Quantiles", precipitation = "Quantiles",
    wind_speed = "Quantiles", wind_direction = "CircularStats", snow_level = "Quantiles",
    slr = "Quantiles", snowfall = "Quantiles", interpolated = "lgl"
  ),
  ModelStats = c(
    temperature = "Quantiles", dewpoint = "Quantiles", precipitation = "Quantiles",
    wind_speed = "Quantiles", wind_direction = "CircularStats", snow_level = "Quantiles",
    slr = "Quantiles", snowfall = "Quantiles", interpolated = "lgl"
  ),
  HourProvenance = c(
    densified = "lgl", ngr = "chr[]", fallback = "chr[]", borrowed = "chr[]",
    spread_floored = "chr[]", floor_clamped = "chr[]", bucket_split = "chr[]",
    distribution_parameters = "chr[]", spread_interpolated = "chr[]",
    interpolated_contributor = "chr[]", moment_matched_family = "chr[]",
    lapse_profile = "chr[]", lapse_climatology = "chr[]", lapse_prism = "chr[]",
    spread_clamped_low = "chr[]", spread_clamped_high = "chr[]", gust_dressed = "chr[]"
  ),
  Sector = c(from = "num!", to = "num!"),
  CircularStats = c(mean = "num!", stddev = "num", sector_50 = "Sector!", sector_90 = "Sector!"),
  MemberForecast = c(
    member_id = "int!", temperature = "num!", precipitation = "num!", precipitation_hours = "int",
    wind_speed = "num", wind_direction = "num", snow_level = "num!", slr = "num",
    snowfall = "num", cumulative_precipitation = "num", cumulative_snowfall = "num"
  ),
  MembersCumulative = c(precipitation = "Quantiles", snowfall = "Quantiles"),
  InversionInfo = c(kind = "chr!", depth = "num!", strength = "num!"),
  PrecipType = c(type = "chr!", snow_probability = "num!", rain_probability = "num!"),
  EnsembleStats = c(
    temperature = "Quantiles!", feels_like = "Quantiles", dewpoint = "Quantiles!",
    precipitation = "Quantiles!", wind_speed = "Quantiles!", wind_gust = "Quantiles",
    wind_direction = "CircularStats!", snow_level = "Quantiles!", slr = "Quantiles",
    snowfall = "Quantiles", cloud_cover = "Quantiles", skin_temperature = "Quantiles",
    mslp = "Quantiles", cape = "Quantiles", relative_humidity = "Quantiles"
  ),
  # One shape for the three FreezingLevel variants, told apart by `kind`.
  FreezingLevel = c(kind = "chr!", height = "num", above_freezing_layer_aloft = "lgl", top = "num"),
  DailyForecast = c(
    date = "date!", condition = "chr!", condition_text = "chr!", condition_icon = "chr!",
    precipitation_type = "chr", high = "Quantiles!", low = "Quantiles!",
    feels_like_high = "Quantiles", feels_like_low = "Quantiles",
    total_precipitation = "Quantiles!", total_snowfall = "Quantiles",
    precipitation_probability = "num!", precipitation_occurrence_probability = "num!",
    snow_probability = "num!", snow_level_mean = "num!", snow_level = "Quantiles",
    total_precipitation_if_wet = "Quantiles", total_snowfall_if_wet = "Quantiles",
    precipitation_display = "PrecipDisplay!",
    cloud_cover_mean = "num", wind = "DailyWind", storm_orientation = "chr",
    storm_orientation_description = "chr", astro = "DailyAstro!",
    temperature_climatology = "DayClimatology"
  ),
  DailyWind = c(
    status = "chr!", peak_speed = "num!", peak_speed_p90 = "num", is_gust = "lgl!",
    sustained_speed = "num"
  ),
  DailyAstro = c(
    sunrise = "dttm", sunset = "dttm", moon_phase = "chr!", moon_illumination = "num!",
    astronomical_season = "chr!"
  ),
  DayClimatology = c(mean = "num!", std = "num!"),
  ElevationForecast = c(
    name = "chr!", elevation = "num!", lat = "num!", lon = "num!",
    hourly = "TimeSeriesPoint[]", daily = "DailyForecast[]", snow_outlook = "SnowOutlook"
  ),
  SearchHit = c(
    key = "chr!", slug = "chr!", state = "chr!", name = "chr!", lat = "num!", lon = "num!",
    elevation_m = "num!", type = "chr!", timezone = "chr!", county = "chr!"
  ),
  PublicCatalogLocation = c(
    slug = "chr!", state = "chr!", name = "chr!", lat = "num!", lon = "num!",
    elevation_m = "num!", type = "chr!", timezone = "chr!", county = "chr", country = "chr",
    aliases = "chr[]", description_short = "chr", description_long = "chr",
    microclimate_notes = "chr", meta_title = "chr", meta_description = "chr",
    best_seasons = "chr[]", key_factors = "chr[]", tags = "chr[]", external_links = "json",
    is_featured = "lgl"
  ),
  PublicCatalogLocationDetail = c(
    slug = "chr!", state = "chr!", name = "chr!", lat = "num!", lon = "num!",
    elevation_m = "num!", type = "chr!", timezone = "chr!", county = "chr", country = "chr",
    aliases = "chr[]", description_short = "chr", description_long = "chr",
    microclimate_notes = "chr", meta_title = "chr", meta_description = "chr",
    best_seasons = "chr[]", key_factors = "chr[]", tags = "chr[]", external_links = "json",
    is_featured = "lgl", elevations = "PublicCatalogElevation[]!", photos = "PublicCatalogPhoto[]!",
    webcams = "PublicCatalogWebcam[]!", nearby_stations = "PublicCatalogNearbyStation[]!",
    template = "CatalogTemplateSummary", content = "CatalogResolvedEntry[]"
  ),
  PublicCatalogStation = c(
    slug = "chr!", state = "chr!", name = "chr!", lat = "num!", lon = "num!",
    elevation_m = "num!", type = "chr!", timezone = "chr!", county = "chr", country = "chr",
    aliases = "chr[]", network = "chr", source_station_id = "chr", elevation_msl_m = "num",
    sensor_height_agl_m = "num", sensor_capabilities = "chr[]", station_status = "chr",
    last_report_at = "dttm", last_report_summary = "json", install_date = "date",
    decommission_date = "date", update_frequency_minutes = "int", station_url = "chr",
    data_url = "chr", description_short = "chr", description_long = "chr", meta_title = "chr",
    meta_description = "chr", tags = "chr[]", is_featured = "lgl"
  ),
  PublicCatalogStationDetail = c(
    slug = "chr!", state = "chr!", name = "chr!", lat = "num!", lon = "num!",
    elevation_m = "num!", type = "chr!", timezone = "chr!", county = "chr", country = "chr",
    aliases = "chr[]", network = "chr", source_station_id = "chr", elevation_msl_m = "num",
    sensor_height_agl_m = "num", sensor_capabilities = "chr[]", station_status = "chr",
    last_report_at = "dttm", last_report_summary = "json", install_date = "date",
    decommission_date = "date", update_frequency_minutes = "int", station_url = "chr",
    data_url = "chr", description_short = "chr", description_long = "chr", meta_title = "chr",
    meta_description = "chr", tags = "chr[]", is_featured = "lgl",
    photos = "PublicCatalogPhoto[]!", webcams = "PublicCatalogWebcam[]!",
    primary_location = "PublicCatalogPrimaryLocation", template = "CatalogTemplateSummary",
    content = "CatalogResolvedEntry[]"
  ),
  PublicCatalogPrimaryLocation = c(
    slug = "chr!", name = "chr!", lat = "num!", lon = "num!", elevation_m = "num!", type = "chr!"
  ),
  PublicCatalogElevation = c(
    label = "chr!", elevation_m = "num!", lat_override = "num", lon_override = "num",
    is_default = "lgl!"
  ),
  PublicCatalogPhoto = c(
    url = "chr!", caption = "chr", credit = "chr", alt_text = "chr", license = "chr",
    license_url = "chr"
  ),
  PublicCatalogWebcam = c(
    name = "chr!", url = "chr!", embed_type = "chr", provider = "chr",
    refresh_interval_seconds = "int"
  ),
  PublicCatalogNearbyStation = c(
    slug = "chr!", name = "chr!", network = "chr!", station_status = "chr!",
    distance_km = "num", elevation_diff_m = "num", is_primary = "lgl!"
  ),
  CmsTemplateSection = c(kind = "chr!", key = "chr!", config = "json"),
  CatalogTemplateSummary = c(
    id = "chr!", location_type = "chr!", template_variant = "chr!",
    spec = "CmsTemplateSection[]!"
  ),
  CatalogResolvedEntry = c(
    id = "chr!", content_type_key = "chr!", title = "chr!", body = "json!", slot = "chr!",
    display_order = "int!", resolved_locale = "chr!", updated_at = "dttm!"
  )
)

# Nested objects flattened into the parent's columns without a prefix: the
# hourly series reads `temperature_p10`, not `ensemble_temperature_p10`.
inline_fields <- c("TimeSeriesPoint.ensemble")

# Nested objects flattened under another prefix, where the plain one would
# collide: a day's `snow_level_mean` (a number) and `snow_level` (a
# distribution, whose mean would also be `snow_level_mean`).
column_prefixes <- c("DailyForecast.snow_level" = "snow_level_dist_")
