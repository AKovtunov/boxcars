# frozen_string_literal: true

module Boxcars
  # Consists of an conductor using boxcars.
  class ConductorExecuter < EngineBoxcar
    attr_accessor :conductor, :boxcars, :return_intermediate_steps, :max_iterations, :early_stopping_method

    # @param conductor [Boxcars::Conductor] The conductor to use.
    # @param boxcars [Array<Boxcars::Boxcar>] The boxcars to use.
    # @param return_intermediate_steps [Boolean] Whether to return the intermediate steps. Defaults to false.
    # @param max_iterations [Integer] The maximum number of iterations to run. Defaults to nil.
    # @param early_stopping_method [String] The early stopping method to use. Defaults to "force".
    def initialize(conductor:, boxcars:, return_intermediate_steps: false, max_iterations: nil,
                   early_stopping_method: "force")
      @conductor = conductor
      @boxcars = boxcars
      @return_intermediate_steps = return_intermediate_steps
      @max_iterations = max_iterations
      @early_stopping_method = early_stopping_method
      # def initialize(prompt:, engine:, output_key: "text", name: nil, description: nil)
      super(prompt: conductor.prompt, engine: conductor.engine, name: conductor.name, description: conductor.description)
    end

    def same_boxcars?(boxcar_names)
      conductor.allowed_boxcars.sort == boxcar_names
    end

    def validate_boxcars
      boxcar_names = boxcars.map(&:name).sort
      return if same_boxcars?(boxcar_names)

      raise "Allowed boxcars (#{conductor.allowed_boxcars}) different than provided boxcars (#{boxcar_names})"
    end

    def input_keys
      conductor.input_keys
    end

    def output_keys
      return conductor.return_values + ["intermediate_steps"] if return_intermediate_steps

      conductor.return_values
    end

    def should_continue?(iterations)
      return true if max_iterations.nil?

      iterations < max_iterations
    end

    # handler before returning
    def pre_return(output, intermediate_steps)
      puts output.log.colorize(:yellow)
      final_output = output.return_values
      final_output["intermediate_steps"] = intermediate_steps if return_intermediate_steps
      final_output
    end

    def engine_prefix(return_direct)
      return_direct ? "" : conductor.engine_prefix
    end

    def call(inputs:)
      conductor.prepare_for_new_call
      name_to_boxcar_map = boxcars.to_h { |boxcar| [boxcar.name, boxcar] }
      intermediate_steps = []
      iterations = 0
      while should_continue?(iterations)
        output = conductor.plan(intermediate_steps, **inputs)
        return pre_return(output, intermediate_steps) if output.is_a?(ConductorFinish)

        if (boxcar = name_to_boxcar_map[output.boxcar])
          begin
            observation = boxcar.run(output.boxcar_input)
            return_direct = boxcar.return_direct
          rescue StandardError => e
            puts "Error in #{boxcar.name} boxcar#call: #{e}".colorize(:red)
            raise e
          end
        else
          observation = "#{output.boxcar} is not a valid boxcar, try another one."
          return_direct = false
        end
        puts "#Observation: #{observation}".colorize(:green)
        intermediate_steps.append([output, observation])
        if return_direct
          output = ConductorFinish.new({ conductor.return_values[0] => observation }, "")
          return pre_return(output, intermediate_steps)
        end
        iterations += 1
      end
      output = conductor.return_stopped_response(early_stopping_method, intermediate_steps, **inputs)
      pre_return(output, intermediate_steps)
    end
  end
end
