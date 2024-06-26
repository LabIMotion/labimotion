module Labimotion
  ## Converter State
  class Units
    FIELDS = [
      {
        "type": "numeric",
        "field": "acceleration",
        "label": "Acceleration",
        "default": "",
        "position": 10,
        "placeholder": "acceleration",
        "units": [{ "key": "mm_s2", "label": "mm/s<sup>2</sup>" }]
      },
      {
        "type": "numeric",
        "field": "agitation",
        "label": "Agitation",
        "default": "",
        "position": 20,
        "placeholder": "agitation",
        "units": [{ "key": "rpm", "label": "rpm" }]
      },
      {
        "type": "numeric",
        "field": "amount_enzyme",
        "label": "Amount enzyme as μmol/min",
        "default": "",
        "position": 30,
        "placeholder": "amount enzyme as μmol/min",
        "units": [
          { "key": "u", "label": "U", "nm": 1 },
          { "key": "mu", "label": "mU", "nm": 1000 },
          { "key": "kat", "label": "kat", "nm": 1.667e-8 },
          { "key": "mkat", "label": "mkat", "nm": 1.667e-5 },
          { "key": "µkat", "label": "µkat", "nm": 0.01667 },
          { "key": "nkat", "label": "nkat", "nm": 16.67 }
        ]
      },
      {
        "type": "numeric",
        "field": "amount_substance",
        "label": "Amount of substance",
        "default": "",
        "position": 35,
        "placeholder": "amount of substance",
        "units": [
          { "key": "mol", "label": "mol", "nm": 1 },
          { "key": "mmol", "label": "mmol", "nm": 1000 },
          { "key": "umol", "label": "µmol", "nm": 1000000 },
          { "key": "nmol", "label": "nmol", "nm": 1.0e9 },
          { "key": "pmol", "label": "pmol", "nm": 1.0e12 }
        ]
      },
      {
        "type": "numeric",
        "field": "molarity",
        "label": "Chem. concentration (Molarity)",
        "default": "",
        "position": 40,
        "placeholder": "molarity",
        "units": [
          { "key": "mol_l", "label": "mol/L", "nm": 1 },
          { "key": "mmol_l", "label": "mmol/L", "nm": 1000 },
          { "key": "umol_l", "label": "µmol/L", "nm": 1000000 },
          { "key": "nmol_l", "label": "nmol/L", "nm": 1000000000 },
          { "key": "pmol_l", "label": "pmol/L", "nm": 1000000000000 }
        ]
      },
      {
        "type": "numeric",
        "field": "chem_distances",
        "label": "Chem. distances",
        "default": "",
        "position": 50,
        "placeholder": "Chem. distances",
        "units": [{ "key": "angstrom", "label": "Å" }]
      },
      {
        "type": "numeric",
        "field": "concentration",
        "label": "Concentration",
        "default": "",
        "position": 60,
        "placeholder": "concentration",
        "units": [
          { "key": "ng_l", "label": "ng/L", "nm": 1000000 },
          { "key": "mg_l", "label": "mg/L", "nm": 1000 },
          { "key": "g_l", "label": "g/L", "nm": 1 }
        ]
      },
      {
        "type": "numeric",
        "field": "conductivity",
        "label": "Conductivity",
        "default": "",
        "position": 66,
        "placeholder": "conductivity",
        "units": [{ "key": "s_m", "label": "S/m", "nm": 1 }]
      },
      {
        "type": "numeric",
        "field": "current",
        "label": "Current",
        "default": "",
        "position": 60,
        "placeholder": "Current",
        "units": [
          { "key": "A", "label": "A", "nm": 1 },
          { "key": "mA", "label": "mA", "nm": 1000 },
          { "key": "uA", "label": "µA", "nm": 1000000 },
          { "key": "nA", "label": "nA", "nm": 1000000000 }
        ]
      },
      {
        "type": "numeric",
        "field": "degree",
        "label": "Degree",
        "default": "",
        "position": 70,
        "placeholder": "degree",
        "units": [{ "key": "degree", "label": "°" }]
      },
      {
        "type": "numeric",
        "field": "density",
        "label": "Density",
        "default": "",
        "position": 75,
        "placeholder": "density",
        "units": [
          { "key": "g_cm3", "label": "g/cm<sup>3</sup>", "nm": 1 },
          { "key": "kg_l", "label": "kg/l", "nm": 1 }
        ]
      },
      {
        "type": "numeric",
        "field": "duration",
        "label": "Duration",
        "default": "",
        "position": 80,
        "placeholder": "duration",
        "units": [
          { "key": "d", "label": "d", "nm": 1 },
          { "key": "h", "label": "h", "nm": 24 },
          { "key": "min", "label": "m", "nm": 1440 },
          { "key": "s", "label": "s", "nm": 86400 }
        ]
      },
      {
        "type": "numeric",
        "field": "elastic_modulus",
        "label": "Elastic modulus",
        "default": "",
        "position": 84,
        "placeholder": "Elastic modulus",
        "units": [
          { "key": "m_pa", "label": "MPa", "nm": 1 },
          { "key": "k_pa", "label": "kPa", "nm": 1000 },
          { "key": "pa", "label": "Pa", "nm": 1000000 }
        ]
      },
      {
        "type": "numeric",
        "field": "electric_charge_c",
        "label": "Electric Charge in C",
        "default": "",
        "position": 85,
        "placeholder": "Electric Charge in C",
        "units": [{ "key": "ec_c", "label": "C", "nm": 1 }]
      },
      {
        "type": "numeric",
        "field": "electric_charge_mol",
        "label": "Electric Charge per mol",
        "default": "",
        "position": 85,
        "placeholder": "Electric Charge per mol",
        "units": [{ "key": "ec_mol", "label": "C/mol", "nm": 1 }]
      },
      {
        "type": "numeric",
        "field": "electric_field",
        "label": "Electric field",
        "default": "",
        "position": 86,
        "placeholder": "Electric field",
        "units": [{ "key": "v_m", "label": "V/m", "nm": 1 }]
      },
      {
        "type": "numeric",
        "field": "energy",
        "label": "Energy",
        "default": "",
        "position": 88,
        "placeholder": "Joule",
        "units": [
          { "key": "eV", "label": "eV", "nm": 6.241509e21 },
          { "key": "keV", "label": "keV", "nm": 6.241509e18 },
          { "key": "j", "label": "J", "nm": 1000 },
          { "key": "k_j", "label": "kJ", "nm": 1 }
        ]
      },
      {
        "type": "numeric",
        "field": "enzyme_activity",
        "label": "Enzyme activity",
        "default": "",
        "position": 90,
        "placeholder": "Enzyme activity",
        "units": [
          { "key": "u_l", "label": "U/L", "nm": 1 },
          { "key": "u_ml", "label": "U/mL", "nm": 1000 }
        ]
      },
      {
        "type": "numeric",
        "field": "faraday",
        "label": "Faraday (Fd)",
        "default": "",
        "position": 95,
        "placeholder": "Faraday (Fd)",
        "units": [
          { "key": "faraday", "label": "Fd", "nm": 1 }
        ]
      },
      {
        "type": "numeric",
        "field": "flow_rate",
        "label": "Flow rate",
        "default": "",
        "position": 100,
        "placeholder": "Flow rate",
        "units": [
          { "key": "ul_min", "label": "µl/min", "nm": 1000000 },
          { "key": "ml_min", "label": "ml/min", "nm": 1000 },
          { "key": "l_m", "label": "l/m", "nm": 1 }
        ]
      },
      {
        "type": "numeric",
        "field": "frequency",
        "label": "Frequency",
        "default": "",
        "position": 100,
        "placeholder": "frequency",
        "units": [
          { "key": "mhz", "label": "MHz", "nm": 1000000 },
          { "key": "hz", "label": "Hz", "nm": 1000 },
          { "key": "khz", "label": "kHz", "nm": 1 }
        ]
      },
      {
        "type": "numeric",
        "field": "heating_rate",
        "label": "Heating rate",
        "default": "",
        "position": 106,
        "placeholder": "heating rate",
        "units": [{ "key": "k_min", "label": "K/min", "nm": 1 }]
      },
      {
        "type": "numeric",
        "field": "length",
        "label": "Length",
        "default": "",
        "position": 110,
        "placeholder": "length",
        "units": [
          { "key": "mm", "label": "mm", "nm": 1000 },
          { "key": "cm", "label": "cm", "nm": 100 },
          { "key": "m", "label": "m", "nm": 1 }
        ]
      },
      {
        "type": "numeric",
        "field": "magnetic_flux_density",
        "label": "Magnetic flux density/inductivity",
        "default": "",
        "position": 120,
        "placeholder": "",
        "units": [{ "key": "T", "label": "T", "nm": 1 }]
      },
      {
        "type": "numeric",
        "field": "mass",
        "label": "Mass",
        "default": "",
        "position": 120,
        "placeholder": "mass",
        "units": [
          { "key": "g", "label": "g", "nm": 1 },
          { "key": "mg", "label": "mg", "nm": 1000 },
          { "key": "ug", "label": "µg", "nm": 1000000 }
        ]
      },
      {
        "type": "numeric",
        "field": "mass_molecule",
        "label": "Mass of molecule",
        "default": "",
        "position": 126,
        "placeholder": "mass of molecule",
        "units": [
          { "key": "dalton", "label": "D", "nm": 1000 },
          { "key": "kilo_dalton", "label": "kD", "nm": 1 }
        ]
      },
      {
        "type": "numeric",
        "field": "molecular_weight",
        "label": "Molecular weight",
        "default": "",
        "position": 130,
        "placeholder": "Molecular weight",
        "units": [{ "key": "g_mol", "label": "g/mol" }]
      },
      {
        "type": "numeric",
        "field": "percentage",
        "label": "Percentage",
        "default": "",
        "position": 136,
        "placeholder": "percentage",
        "units": [{ "key": "p", "label": "%", "nm": 1 }]
      },
      {
        "type": "numeric",
        "field": "pressure",
        "label": "Pressure",
        "default": "",
        "position": 140,
        "placeholder": "pressure",
        "units": [
          { "key": "atm", "label": "atm", "nm": 1 },
          { "key": "pa", "label": "Pa", "nm": 101325 },
          { "key": "torr", "label": "Torr", "nm": 760 }
        ]
      },
      {
        "type": "numeric",
        "field": "reaction_rate",
        "label": "Reaction rate",
        "default": "",
        "position": 150,
        "placeholder": "Reaction rate",
        "units": [
          { "key": "mol_lmin", "label": "mol/Lmin", "nm": 1 },
          { "key": "mol_lsec", "label": "mol/Ls", "nm": 60 }
        ]
      },
      {
        "type": "numeric",
        "field": "specific_volume",
        "label": "Specific Volume",
        "default": "",
        "position": 160,
        "placeholder": "Specific Volume",
        "units": [{ "key": "cm3_g", "label": "cm<sup>3</sup>/g", "nm": 1 }]
      },
      {
        "type": "numeric",
        "field": "speed",
        "label": "Speed",
        "default": "",
        "position": 165,
        "placeholder": "speed",
        "units": [
          { "key": "cm_s", "label": "cm/s", "nm": 1 },
          { "key": "mm_s", "label": "mm/s", "nm": 10 },
          { "key": "um_m", "label": "µm/min", "nm": 600000 },
          { "key": "nm_m", "label": "nm/min", "nm": 60000000 },
          { "key": "cm_h", "label": "cm/h", "nm": 3600 },
          { "key": "mm_h", "label": "mm/h", "nm": 36000 }
        ]
      },
      {
        "type": "numeric",
        "field": "subatomic_length",
        "label": "Subatomic length",
        "default": "",
        "position": 168,
        "placeholder": "Subatomic length",
        "units": [
          { "key": "um", "label": "µm", "nm": 1 },
          { "key": "nm", "label": "nm", "nm": 1000 },
          { "key": "pm", "label": "pm", "nm": 1000000 }
        ]
      },
      {
        "type": "numeric",
        "field": "surface",
        "label": "Surface",
        "default": "",
        "position": 170,
        "placeholder": "surface",
        "units": [
          { "key": "a_2", "label": "A<sup>2</sup>", "nm": 1.0e16 },
          { "key": "um_2", "label": "µm<sup>2</sup>", "nm": 1.0e8 },
          { "key": "mm_2", "label": "mm<sup>2</sup>", "nm": 100 },
          { "key": "cm_2", "label": "cm<sup>2</sup>", "nm": 1 }
        ]
      },
      {
        "type": "numeric",
        "field": "temperature",
        "label": "Temperature",
        "default": "",
        "position": 180,
        "placeholder": "temperature",
        "units": [
          { "key": "C", "label": "°C" },
          { "key": "F", "label": "°F" },
          { "key": "K", "label": "K" }
        ]
      },
      {
        "type": "numeric",
        "field": "turnover_number",
        "label": "Turnover number",
        "default": "",
        "position": 190,
        "placeholder": "Turnover number",
        "units": [{ "key": "1_s", "label": "1/s", "nm": 1 }, { "key": "1_m", "label": "1/m", "nm": 60 }]
      },
      {
        "type": "numeric",
        "field": "viscosity",
        "label": "Dynamic Viscosity",
        "default": "",
        "position": 200,
        "placeholder": "Dynamic Viscosity",
        "units": [
          { "key": "pas", "label": "Pas", "nm": 1 },
          { "key": "mpas", "label": "mPas", "nm": 1000 }
        ]
      },
      {
        "type": "numeric",
        "field": "kinematic_viscosity",
        "label": "Kinematic Viscosity",
        "default": "",
        "position": 205,
        "placeholder": "Kinematic Viscosity",
        "units": [{ "key": "m2_s", "label": "m<sup>2</sup>/s", "nm": 1 }]
      },
      {
        "type": "numeric",
        "field": "voltage",
        "label": "Voltage",
        "default": "",
        "position": 200,
        "placeholder": "voltage",
        "units": [
          { "key": "mv", "label": "mV", "nm": 1000 },
          { "key": "v", "label": "V", "nm": 1 }
        ]
      },
      {
        "type": "numeric",
        "field": "volumes",
        "label": "Volumes",
        "default": "",
        "position": 210,
        "placeholder": "volume",
        "units": [
          { "key": "l", "label": "l", "nm": 1 },
          { "key": "ml", "label": "ml", "nm": 1000 },
          { "key": "ul", "label": "µl", "nm": 1000000 },
          { "key": "nl", "label": "nl", "nm": 1000000000 }
        ]
      }
    ]
  end
end
