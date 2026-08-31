// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: tool/device_display_model/model_manifest.json
// Fingerprint: fnv1a64:d64e40e85e00179d

part of 'device_display_estimator.dart';

final class _DeviceDisplayEstimatorModel {
  static const safeInsetMultiplier = 0.9;
  static const iosCandidateKind = 'constrained_blend';
  static const androidCandidateKind = 'robust_quadratic_regression';
  static const _iosUsesSafetyPipeline = true;
  static const _androidUsesSafetyPipeline = true;
  static const Map<String, Object?> _iosHead = <String, Object?>{
    'featureCenters': <Object?>[
      0.773547605997983,
      7.095064377287131,
      6.025865973825314,
      1.0986122886681098,
      1.0,
      0.26666666666666666,
      0.26666666666666666,
      0.1642512077294686,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      1.0,
    ],
    'featureScales': <Object?>[
      0.0022859475894296422,
      0.06494176835333308,
      0.05621905760683656,
      1.0,
      1.0,
      0.049797251908396976,
      0.049797251908396976,
      0.009061166161105508,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
    ],
    'gam': <String, Object?>{
      'coefficients': <Object?>[
        0.005175644636620647,
        0.00721193345089163,
        0.005521238292859936,
        0.004805207644191711,
        -0.0006773416896756027,
        0.0002810010188649044,
        -0.0006261767151272845,
        0.0021979975269488775,
        0.0017476442737082059,
        0.0003726367901115255,
        0.0,
        0.012880368567417318,
        0.0031015569351954555,
        0.0005710876013779102,
        0.012880368567417318,
        0.0031015569351954555,
        0.0005710876013779102,
        0.0006180504011578223,
        -0.00025544919473953427,
        -0.0010561482372327283,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
      ],
      'intercept': 0.24833440175545404,
      'kind': 'spline_gam',
      'knots': <Object?>[
        <Object?>[-0.7859178145237673, -0.6444447174462657, 0.10031243197869255, 1.3476603981546569],
        <Object?>[-5.790591054679388, -0.3486581490446562, 0.6744907594765952, 1.3908250511729345],
        <Object?>[-1.7599005046799627, -0.5232013210181625, 0.2559405665019529, 1.0834182513864379],
        <Object?>[],
        <Object?>[],
        <Object?>[-1.0865314474133287, -0.5149084469197779, 0.30426408227077767, 1.1475102531355057],
        <Object?>[-1.0865314474133287, -0.5149084469197779, 0.30426408227077767, 1.1475102531355057],
        <Object?>[-1.0711373140551608, -0.258956273727621, 0.5411026615204019, 1.885201672737081],
        <Object?>[],
        <Object?>[],
        <Object?>[],
        <Object?>[],
        <Object?>[],
        <Object?>[],
        <Object?>[],
        <Object?>[],
        <Object?>[],
      ],
    },
    'kind': 'constrained_blend',
    'trees': <String, Object?>{
      'bias': 0.24920560747663548,
      'kind': 'shallow_boosted_tree',
      'learningRate': 0.1,
      'trees': <Object?>[
        <Object?>[
          0.0,
          0.050156215989346276,
          1.0,
          4.0,
          0.003999804324861947,
          1.0,
          0.7089812496947685,
          2.0,
          3.0,
          -0.018505827904094573,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          -0.029410828359076012,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.0033041730058683133,
          5.0,
          0.7568573379744151,
          5.0,
          6.0,
          0.03775825266829674,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.031652592847213695,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.043863912489379805,
        ],
        <Object?>[
          0.0,
          0.050156215989346276,
          1.0,
          4.0,
          0.0036671039772960268,
          1.0,
          0.7089812496947685,
          2.0,
          3.0,
          -0.017635606058987646,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          -0.027940286941122213,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.0029737557052814806,
          5.0,
          0.7568573379744151,
          5.0,
          6.0,
          0.03562116903172156,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.028487333562492334,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.04275500450095078,
        ],
        <Object?>[
          0.0,
          -0.21288585338011745,
          1.0,
          4.0,
          0.003256788718773864,
          0.0,
          -0.6594677384614305,
          2.0,
          3.0,
          -0.021184874983435128,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          -0.0006901700498909702,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          -0.03484801160579791,
          5.0,
          0.7568573379744151,
          5.0,
          6.0,
          0.027698452420982872,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.019085917851035944,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.04061725427590325,
        ],
        <Object?>[
          0.0,
          0.050156215989346276,
          1.0,
          4.0,
          0.0029888022735975284,
          5.0,
          -0.5787570943378304,
          2.0,
          3.0,
          -0.015790796205086638,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          -0.02837615688483417,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          -0.000059095355402227846,
          5.0,
          0.7568573379744151,
          5.0,
          6.0,
          0.031158199991623788,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.02373000842113948,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.038586391562108094,
        ],
        <Object?>[
          0.0,
          0.050156215989346276,
          1.0,
          4.0,
          0.002672617912404173,
          5.0,
          -0.5787570943378304,
          2.0,
          3.0,
          -0.014684652532658542,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          -0.02638982590289578,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          -0.00005318581986199566,
          5.0,
          0.7568573379744151,
          5.0,
          6.0,
          0.028708523579998254,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.021357007579025533,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.03606003958097098,
        ],
        <Object?>[
          0.0,
          0.050156215989346276,
          1.0,
          4.0,
          0.0021414578621348074,
          1.0,
          0.7089812496947685,
          2.0,
          3.0,
          -0.0136560177111076,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          -0.022734279538084302,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.004500505942845831,
          5.0,
          0.7568573379744151,
          5.0,
          6.0,
          0.025837671221998423,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.019221306821122996,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.032454035622873856,
        ],
        <Object?>[
          5.0,
          -0.5787570943378304,
          1.0,
          4.0,
          0.0017033733842779552,
          1.0,
          -0.30883188477465223,
          2.0,
          3.0,
          -0.023757969775242662,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          -0.029873349712874718,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          -0.019681049816821287,
          0.0,
          0.050156215989346276,
          5.0,
          6.0,
          0.01443404496403827,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.0012042562603977705,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.023253904099798602,
        ],
        <Object?>[
          5.0,
          -0.5787570943378304,
          1.0,
          4.0,
          0.0015330360458501635,
          1.0,
          -0.30883188477465223,
          2.0,
          3.0,
          -0.0213821727977184,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          -0.026886014741587243,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          -0.01771294483513917,
          0.0,
          0.050156215989346276,
          5.0,
          6.0,
          0.012990640467634443,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.001083830634357998,
          -1.0,
          0.0,
          -1.0,
          -1.0,
          0.02092851368981874,
        ],
      ],
    },
    'weight': 0.2,
  };
  static const Map<String, Object?> _androidTopHead = <String, Object?>{
    'coefficients': <Object?>[
      0.0,
      0.0,
      -0.005017016058018426,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0006709670955394736,
      0.0,
      0.0009088031898693292,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
    ],
    'featureCenters': <Object?>[
      0.8025619665458122,
      6.984716320118266,
      6.0196354240746786,
      1.0986122886681098,
      1.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      1.0,
      1.0,
      1.0,
    ],
    'featureScales': <Object?>[
      0.006010861188353024,
      1.0,
      0.05391866924773814,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
    ],
    'intercept': 0.15914299551928415,
    'kind': 'robust_quadratic_regression',
  };
  static const Map<String, Object?> _androidBottomHead = <String, Object?>{
    'coefficients': <Object?>[
      0.0,
      0.0,
      -0.005017016058018426,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0006709670955394736,
      0.0,
      0.0009088031898693292,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
    ],
    'featureCenters': <Object?>[
      0.8025619665458122,
      6.984716320118266,
      6.0196354240746786,
      1.0986122886681098,
      1.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      1.0,
      1.0,
      1.0,
    ],
    'featureScales': <Object?>[
      0.006010861188353024,
      1.0,
      0.05391866924773814,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
    ],
    'intercept': 0.15914299551928415,
    'kind': 'robust_quadratic_regression',
  };
  static const _iosHasChallenger = true;
  static const _androidTopHasChallenger = true;
  static const _androidBottomHasChallenger = true;
  static const Map<String, Object?> _iosChallenger = <String, Object?>{
    'coefficients': <Object?>[
      0.006560038864697359,
      0.00246859309877653,
      0.0008724388965256408,
      0.0,
      0.0,
      0.006950526838999519,
      0.006950526838999519,
      -0.0008910090367828235,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.004436587147284353,
      -0.0007700307962388124,
      0.0,
      0.0,
      0.0,
      0.0009646745174386035,
      0.0009646745174386035,
      -0.000021702383897351906,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
    ],
    'featureCenters': <Object?>[
      0.773547605997983,
      7.095064377287131,
      6.025865973825314,
      1.0986122886681098,
      1.0,
      0.26666666666666666,
      0.26666666666666666,
      0.1642512077294686,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      1.0,
    ],
    'featureScales': <Object?>[
      0.0022859475894296422,
      0.06494176835333308,
      0.05621905760683656,
      1.0,
      1.0,
      0.049797251908396976,
      0.049797251908396976,
      0.009061166161105508,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
    ],
    'intercept': 0.2519754878891456,
    'kind': 'robust_quadratic_regression',
  };
  static const Map<String, Object?> _androidTopChallenger = <String, Object?>{
    'bias': 0.16111111111111112,
    'featureCenters': <Object?>[
      0.8025619665458122,
      6.984716320118266,
      6.0196354240746786,
      1.0986122886681098,
      1.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      1.0,
      1.0,
      1.0,
    ],
    'featureScales': <Object?>[
      0.006010861188353024,
      1.0,
      0.05391866924773814,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
    ],
    'kind': 'shallow_boosted_tree',
    'learningRate': 0.1,
    'trees': <Object?>[
      <Object?>[
        0.0,
        -0.3372453797382976,
        1.0,
        2.0,
        0.0007387152777777786,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.008639756944444452,
        0.0,
        0.4904505644342619,
        3.0,
        4.0,
        -0.003211805555555558,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        -0.006423611111111116,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.0,
      ],
      <Object?>[
        0.0,
        -0.3372453797382976,
        1.0,
        2.0,
        0.0009528356481481454,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.008639756944444452,
        0.0,
        0.4904505644342619,
        3.0,
        4.0,
        -0.0028906250000000078,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        -0.0057812500000000155,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.0,
      ],
      <Object?>[
        0.0,
        -0.3372453797382976,
        1.0,
        2.0,
        0.0011455439814814828,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.008639756944444452,
        0.0,
        0.4904505644342619,
        3.0,
        4.0,
        -0.0026015625000000014,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        -0.005203125000000003,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.0,
      ],
      <Object?>[
        0.0,
        -0.3372453797382976,
        1.0,
        2.0,
        0.0013189814814814859,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.008639756944444452,
        0.0,
        0.4904505644342619,
        3.0,
        4.0,
        -0.002341406249999997,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        -0.004682812499999994,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.0,
      ],
      <Object?>[
        0.0,
        -0.3372453797382976,
        1.0,
        2.0,
        0.0014750752314814884,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.008639756944444452,
        0.0,
        0.4904505644342619,
        3.0,
        4.0,
        -0.0021072656249999933,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        -0.0042145312499999865,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.0,
      ],
      <Object?>[
        0.0,
        -0.3372453797382976,
        1.0,
        2.0,
        0.001615559606481488,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.008639756944444452,
        0.0,
        0.4904505644342619,
        3.0,
        4.0,
        -0.001896539062499994,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        -0.003793078124999988,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.0,
      ],
      <Object?>[
        0.0,
        -0.3372453797382976,
        1.0,
        2.0,
        0.0017419955439814904,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.008639756944444452,
        0.0,
        0.4904505644342619,
        3.0,
        4.0,
        -0.0017068851562499904,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        -0.0034137703124999808,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.0,
      ],
      <Object?>[
        0.0,
        -0.3372453797382976,
        1.0,
        2.0,
        0.0018557878877314925,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.008639756944444452,
        0.0,
        0.4904505644342619,
        3.0,
        4.0,
        -0.0015361966406249872,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        -0.0030723932812499744,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.0,
      ],
    ],
  };
  static const Map<String, Object?> _androidBottomChallenger = <String, Object?>{
    'bias': 0.16111111111111112,
    'featureCenters': <Object?>[
      0.8025619665458122,
      6.984716320118266,
      6.0196354240746786,
      1.0986122886681098,
      1.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      1.0,
      1.0,
      1.0,
    ],
    'featureScales': <Object?>[
      0.006010861188353024,
      1.0,
      0.05391866924773814,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
    ],
    'kind': 'shallow_boosted_tree',
    'learningRate': 0.1,
    'trees': <Object?>[
      <Object?>[
        0.0,
        -0.3372453797382976,
        1.0,
        2.0,
        0.0007387152777777786,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.008639756944444452,
        0.0,
        0.4904505644342619,
        3.0,
        4.0,
        -0.003211805555555558,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        -0.006423611111111116,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.0,
      ],
      <Object?>[
        0.0,
        -0.3372453797382976,
        1.0,
        2.0,
        0.0009528356481481454,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.008639756944444452,
        0.0,
        0.4904505644342619,
        3.0,
        4.0,
        -0.0028906250000000078,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        -0.0057812500000000155,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.0,
      ],
      <Object?>[
        0.0,
        -0.3372453797382976,
        1.0,
        2.0,
        0.0011455439814814828,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.008639756944444452,
        0.0,
        0.4904505644342619,
        3.0,
        4.0,
        -0.0026015625000000014,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        -0.005203125000000003,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.0,
      ],
      <Object?>[
        0.0,
        -0.3372453797382976,
        1.0,
        2.0,
        0.0013189814814814859,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.008639756944444452,
        0.0,
        0.4904505644342619,
        3.0,
        4.0,
        -0.002341406249999997,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        -0.004682812499999994,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.0,
      ],
      <Object?>[
        0.0,
        -0.3372453797382976,
        1.0,
        2.0,
        0.0014750752314814884,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.008639756944444452,
        0.0,
        0.4904505644342619,
        3.0,
        4.0,
        -0.0021072656249999933,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        -0.0042145312499999865,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.0,
      ],
      <Object?>[
        0.0,
        -0.3372453797382976,
        1.0,
        2.0,
        0.001615559606481488,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.008639756944444452,
        0.0,
        0.4904505644342619,
        3.0,
        4.0,
        -0.001896539062499994,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        -0.003793078124999988,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.0,
      ],
      <Object?>[
        0.0,
        -0.3372453797382976,
        1.0,
        2.0,
        0.0017419955439814904,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.008639756944444452,
        0.0,
        0.4904505644342619,
        3.0,
        4.0,
        -0.0017068851562499904,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        -0.0034137703124999808,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.0,
      ],
      <Object?>[
        0.0,
        -0.3372453797382976,
        1.0,
        2.0,
        0.0018557878877314925,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.008639756944444452,
        0.0,
        0.4904505644342619,
        3.0,
        4.0,
        -0.0015361966406249872,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        -0.0030723932812499744,
        -1.0,
        0.0,
        -1.0,
        -1.0,
        0.0,
      ],
    ],
  };
  static const Map<String, Object?> _iosPrior = <String, Object?>{'kind': 'safe_inset'};
  static const Map<String, Object?> _androidTopPrior = <String, Object?>{
    'kind': 'logical_radius_median',
    'logicalRadius': 33.0,
  };
  static const Map<String, Object?> _androidBottomPrior = <String, Object?>{
    'kind': 'logical_radius_median',
    'logicalRadius': 33.0,
  };
  static const Map<String, Object?> _iosGate = <String, Object?>{
    'coefficients': <Object?>[
      7.87954195291112,
      1.8819474810155985,
      0.6922219795163067,
      0.0,
      0.0,
      1.9791066749655097,
      1.9791066749655097,
      -0.6033576910918608,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      -8.168949832270028,
      1.8753166887369952,
      2.6011112569813624,
      0.0,
      0.0,
      2.793459767164488,
      2.793459767164488,
      2.1935851467492604,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
    ],
    'featureSchema': <String, Object?>{
      'distanceInner': 33.39638424557584,
      'distanceOuter': 34.39638424557584,
      'madScales': <Object?>[
        0.0014430024326369986,
        0.09291618318301087,
        0.05621905760683656,
        1.0,
        1.0,
        0.0515686956521739,
        0.0515686956521739,
        0.009061166161105508,
        1.0,
        1.0,
        1.0,
        1.0,
        1.0,
        1.0,
        1.0,
        1.0,
        1.0,
      ],
      'medians': <Object?>[
        0.7725743141912671,
        7.095064377287131,
        6.025865973825314,
        1.0986122886681098,
        1.0,
        0.26666666666666666,
        0.26666666666666666,
        0.1642512077294686,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        1.0,
      ],
      'missingDefaults': <Object?>[
        0.7725743141912671,
        7.095064377287131,
        6.025865973825314,
        1.0986122886681098,
        1.0,
        0.26666666666666666,
        0.26666666666666666,
        0.1642512077294686,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        1.0,
      ],
      'names': <Object?>[
        'logDisplayAspectRatio',
        'logPhysicalShortSide',
        'logLogicalShortSide',
        'logDevicePixelRatio',
        'viewportCoverage',
        'maximumViewPaddingDiameterFraction',
        'naturalTopPaddingDiameterFraction',
        'naturalBottomPaddingDiameterFraction',
        'maximumGestureInsetDiameterFraction',
        'cutoutWidthFraction',
        'cutoutHeightFraction',
        'cutoutCountFraction',
        'devicePixelRatioMissing',
        'viewSizeMissing',
        'viewPaddingMissing',
        'systemGestureInsetsMissing',
        'displayCutoutMissing',
      ],
    },
    'fitted': true,
    'intercept': 6.676510181891519,
    'kind': 'quadratic_logistic',
    'priorProbability': 0.846153846153846,
    'threshold': 0.5,
  };
  static const Map<String, Object?> _androidTopGate = <String, Object?>{
    'coefficients': <Object?>[],
    'fitted': false,
    'intercept': 1.3862943611198908,
    'kind': 'constant_logistic',
    'priorProbability': 0.8,
    'threshold': 0.5,
  };
  static const Map<String, Object?> _androidBottomGate = <String, Object?>{
    'coefficients': <Object?>[],
    'fitted': false,
    'intercept': 1.3862943611198908,
    'kind': 'constant_logistic',
    'priorProbability': 0.8,
    'threshold': 0.5,
  };
  static const iosGateThreshold = 0.5;
  static const androidTopGateThreshold = 0.5;
  static const androidBottomGateThreshold = 0.5;
  static const iosModelBlendWeight = 0.5;
  static const androidModelBlendWeight = 0.0;
  static const iosDistanceTransitionScale = 0.25;
  static const androidDistanceTransitionScale = 0.25;
  static const iosDisagreementTransitionScale = 1.0;
  static const androidDisagreementTransitionScale = 0.25;
  static const _iosHasFeatureSchema = true;
  static const _androidHasFeatureSchema = true;
  static const Map<String, Object?> _iosFeatureSchema = <String, Object?>{
    'distanceInner': 33.39638424557584,
    'distanceOuter': 34.39638424557584,
    'madScales': <Object?>[
      0.0014430024326369986,
      0.09291618318301087,
      0.05621905760683656,
      1.0,
      1.0,
      0.0515686956521739,
      0.0515686956521739,
      0.009061166161105508,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
    ],
    'medians': <Object?>[
      0.7725743141912671,
      7.095064377287131,
      6.025865973825314,
      1.0986122886681098,
      1.0,
      0.26666666666666666,
      0.26666666666666666,
      0.1642512077294686,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      1.0,
    ],
    'missingDefaults': <Object?>[
      0.7725743141912671,
      7.095064377287131,
      6.025865973825314,
      1.0986122886681098,
      1.0,
      0.26666666666666666,
      0.26666666666666666,
      0.1642512077294686,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      1.0,
    ],
    'names': <Object?>[
      'logDisplayAspectRatio',
      'logPhysicalShortSide',
      'logLogicalShortSide',
      'logDevicePixelRatio',
      'viewportCoverage',
      'maximumViewPaddingDiameterFraction',
      'naturalTopPaddingDiameterFraction',
      'naturalBottomPaddingDiameterFraction',
      'maximumGestureInsetDiameterFraction',
      'cutoutWidthFraction',
      'cutoutHeightFraction',
      'cutoutCountFraction',
      'devicePixelRatioMissing',
      'viewSizeMissing',
      'viewPaddingMissing',
      'systemGestureInsetsMissing',
      'displayCutoutMissing',
    ],
  };
  static const Map<String, Object?> _androidFeatureSchema = <String, Object?>{
    'distanceInner': 0.7980876555740067,
    'distanceOuter': 1.7980876555740068,
    'madScales': <Object?>[
      0.006010861188353024,
      1.0,
      0.05391866924773814,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
      1.0,
    ],
    'medians': <Object?>[
      0.8025619665458122,
      6.984716320118266,
      6.0196354240746786,
      1.0986122886681098,
      1.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      1.0,
      1.0,
      1.0,
    ],
    'missingDefaults': <Object?>[
      0.8025619665458122,
      6.984716320118266,
      6.0196354240746786,
      1.0986122886681098,
      1.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      1.0,
      1.0,
      1.0,
    ],
    'names': <Object?>[
      'logDisplayAspectRatio',
      'logPhysicalShortSide',
      'logLogicalShortSide',
      'logDevicePixelRatio',
      'viewportCoverage',
      'maximumViewPaddingDiameterFraction',
      'naturalTopPaddingDiameterFraction',
      'naturalBottomPaddingDiameterFraction',
      'maximumGestureInsetDiameterFraction',
      'cutoutWidthFraction',
      'cutoutHeightFraction',
      'cutoutCountFraction',
      'devicePixelRatioMissing',
      'viewSizeMissing',
      'viewPaddingMissing',
      'systemGestureInsetsMissing',
      'displayCutoutMissing',
    ],
  };
  static const iosDisagreementInnerLogicalPixels = 3.064858418102059;
  static const iosDisagreementOuterLogicalPixels = 153.00367256046016;
  static const androidDisagreementInnerLogicalPixels = 0.21382073509690983;
  static const androidDisagreementOuterLogicalPixels = 0.2420998839720101;

  static bool get hasCandidateKinds => iosCandidateKind.isNotEmpty && androidCandidateKind.isNotEmpty;

  static double iosNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
  }) => _predict(_iosHead, features, safeInsetDiameter);

  static double? iosChallengerNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
  }) => !_iosHasChallenger ? null : _predict(_iosChallenger, features, safeInsetDiameter);

  static double iosPriorNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
  }) => _predict(_iosPrior, features, safeInsetDiameter);

  static double androidTopNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
  }) => _predict(_androidTopHead, features, safeInsetDiameter);

  static double androidBottomNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
  }) => _predict(_androidBottomHead, features, safeInsetDiameter);

  static double? androidTopChallengerNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
  }) => !_androidTopHasChallenger ? null : _predict(_androidTopChallenger, features, safeInsetDiameter);

  static double? androidBottomChallengerNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
  }) => !_androidBottomHasChallenger ? null : _predict(_androidBottomChallenger, features, safeInsetDiameter);

  static double androidTopPriorNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
  }) => _predict(_androidTopPrior, features, safeInsetDiameter);

  static double androidBottomPriorNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
  }) => _predict(_androidBottomPrior, features, safeInsetDiameter);

  static double iosRoundedProbability(List<double> features) => _gateProbability(_iosGate, features);

  static double androidTopRoundedProbability(List<double> features) => _gateProbability(_androidTopGate, features);

  static double androidBottomRoundedProbability(List<double> features) =>
      _gateProbability(_androidBottomGate, features);

  static double iosSupportWeight(List<double> features) => _iosHasFeatureSchema
      ? _distanceSupportWeight(
          _iosFeatureSchema,
          features,
          iosDistanceTransitionScale,
        )
      : 0;

  static double androidSupportWeight(List<double> features) => _androidHasFeatureSchema
      ? _distanceSupportWeight(
          _androidFeatureSchema,
          features,
          androidDistanceTransitionScale,
        )
      : 0;

  static double iosPipelineNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
    required double shortestLogicalSide,
  }) {
    final selected = iosNormalizedDiameter(
      features,
      safeInsetDiameter: safeInsetDiameter,
    );
    if (!_iosUsesSafetyPipeline) {
      return selected;
    }
    return _pipelineNormalizedDiameter(
      selectedDiameter: selected,
      challengerDiameter: iosChallengerNormalizedDiameter(
        features,
        safeInsetDiameter: safeInsetDiameter,
      ),
      priorDiameter: iosPriorNormalizedDiameter(
        features,
        safeInsetDiameter: safeInsetDiameter,
      ),
      roundedProbability: iosRoundedProbability(features),
      gateThreshold: iosGateThreshold,
      modelBlendWeight: iosModelBlendWeight,
      distanceSupport: iosSupportWeight(features),
      shortestLogicalSide: shortestLogicalSide,
      disagreementInnerLogicalPixels: iosDisagreementInnerLogicalPixels * iosDisagreementTransitionScale,
      disagreementOuterLogicalPixels: iosDisagreementOuterLogicalPixels * iosDisagreementTransitionScale,
    );
  }

  static double androidTopPipelineNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
    required double shortestLogicalSide,
  }) {
    final selected = androidTopNormalizedDiameter(
      features,
      safeInsetDiameter: safeInsetDiameter,
    );
    if (!_androidUsesSafetyPipeline) {
      return selected;
    }
    return _pipelineNormalizedDiameter(
      selectedDiameter: selected,
      challengerDiameter: androidTopChallengerNormalizedDiameter(
        features,
        safeInsetDiameter: safeInsetDiameter,
      ),
      priorDiameter: androidTopPriorNormalizedDiameter(
        features,
        safeInsetDiameter: safeInsetDiameter,
      ),
      roundedProbability: androidTopRoundedProbability(features),
      gateThreshold: androidTopGateThreshold,
      modelBlendWeight: androidModelBlendWeight,
      distanceSupport: androidSupportWeight(features),
      shortestLogicalSide: shortestLogicalSide,
      disagreementInnerLogicalPixels: androidDisagreementInnerLogicalPixels * androidDisagreementTransitionScale,
      disagreementOuterLogicalPixels: androidDisagreementOuterLogicalPixels * androidDisagreementTransitionScale,
    );
  }

  static double androidBottomPipelineNormalizedDiameter(
    List<double> features, {
    required double safeInsetDiameter,
    required double shortestLogicalSide,
  }) {
    final selected = androidBottomNormalizedDiameter(
      features,
      safeInsetDiameter: safeInsetDiameter,
    );
    if (!_androidUsesSafetyPipeline) {
      return selected;
    }
    return _pipelineNormalizedDiameter(
      selectedDiameter: selected,
      challengerDiameter: androidBottomChallengerNormalizedDiameter(
        features,
        safeInsetDiameter: safeInsetDiameter,
      ),
      priorDiameter: androidBottomPriorNormalizedDiameter(
        features,
        safeInsetDiameter: safeInsetDiameter,
      ),
      roundedProbability: androidBottomRoundedProbability(features),
      gateThreshold: androidBottomGateThreshold,
      modelBlendWeight: androidModelBlendWeight,
      distanceSupport: androidSupportWeight(features),
      shortestLogicalSide: shortestLogicalSide,
      disagreementInnerLogicalPixels: androidDisagreementInnerLogicalPixels * androidDisagreementTransitionScale,
      disagreementOuterLogicalPixels: androidDisagreementOuterLogicalPixels * androidDisagreementTransitionScale,
    );
  }

  static double _pipelineNormalizedDiameter({
    required double selectedDiameter,
    required double? challengerDiameter,
    required double priorDiameter,
    required double roundedProbability,
    required double gateThreshold,
    required double modelBlendWeight,
    required double distanceSupport,
    required double shortestLogicalSide,
    required double disagreementInnerLogicalPixels,
    required double disagreementOuterLogicalPixels,
  }) {
    final support =
        modelBlendWeight *
        math.min(
          distanceSupport,
          disagreementWeight(
            selectedDiameter: selectedDiameter,
            challengerDiameter: challengerDiameter,
            shortestLogicalSide: shortestLogicalSide,
            innerLogicalPixels: disagreementInnerLogicalPixels,
            outerLogicalPixels: disagreementOuterLogicalPixels,
          ),
        );
    final blendedProbability = support * roundedProbability + (1 - support) * (priorDiameter > 0 ? 1 : 0);
    if (blendedProbability < gateThreshold) {
      return 0;
    }
    return (support * selectedDiameter + (1 - support) * priorDiameter).clamp(0, 1);
  }

  static double disagreementWeight({
    required double selectedDiameter,
    required double? challengerDiameter,
    required double shortestLogicalSide,
    required double innerLogicalPixels,
    required double outerLogicalPixels,
  }) {
    if (challengerDiameter == null) {
      return 1;
    }
    final logicalSpread = (selectedDiameter - challengerDiameter).abs() * shortestLogicalSide / 2;
    if (logicalSpread <= innerLogicalPixels) {
      return 1;
    }
    final outer = math.max(outerLogicalPixels, innerLogicalPixels + 0.000001);
    if (logicalSpread >= outer) {
      return 0;
    }
    return (outer - logicalSpread) / (outer - innerLogicalPixels);
  }

  static double _predict(
    Map<String, Object?> model,
    List<double> features,
    double safeInsetDiameter,
  ) {
    final kind = model['kind']! as String;
    if (kind == 'zero') {
      return 0;
    }
    if (kind == 'safe_inset') {
      return safeInsetDiameter.clamp(0, 1);
    }
    if (kind == 'median') {
      return (model['intercept']! as num).toDouble().clamp(0, 1);
    }
    if (kind == 'shortest_side') {
      return (model['normalizedDiameter']! as num).toDouble().clamp(0, 1);
    }
    if (kind == 'logical_radius_median') {
      final logicalShortSide = math.exp(features[2]);
      return (2 * (model['logicalRadius']! as num).toDouble() / logicalShortSide).clamp(0, 1);
    }
    final standardized = _standardize(model, features);
    if (kind == 'linear') {
      return _linearCombination(model, standardized).clamp(0, 1);
    }
    return _predictNormalized(model, standardized).clamp(0, 1);
  }

  static List<double> _standardize(
    Map<String, Object?> model,
    List<double> features,
  ) {
    final schema = model['featureSchema'] as Map<String, Object?>?;
    final centers = (model['featureCenters'] ?? schema?['medians'])! as List<Object?>;
    final scales = (model['featureScales'] ?? schema?['madScales'])! as List<Object?>;
    return <double>[
      for (var index = 0; index < features.length; index += 1)
        (features[index] - (centers[index]! as num).toDouble()) / (scales[index]! as num).toDouble(),
    ];
  }

  static double _predictNormalized(
    Map<String, Object?> model,
    List<double> features,
  ) => switch (model['kind']) {
    'robust_quadratic_regression' => _linearCombination(model, <double>[
      ...features,
      for (final feature in features) feature * feature,
    ]),
    'spline_gam' => _linearCombination(
      model,
      _gamBasis(features, model['knots']! as List<Object?>),
    ),
    'shallow_boosted_tree' => _treeEnsemble(model, features),
    'constrained_blend' =>
      (model['weight']! as num).toDouble() *
              _predictNormalized(
                model['gam']! as Map<String, Object?>,
                features,
              ).clamp(0, 1) +
          (1 - (model['weight']! as num).toDouble()) *
              _predictNormalized(
                model['trees']! as Map<String, Object?>,
                features,
              ).clamp(0, 1),
    _ => throw StateError(
      'Unknown generated display-radius model kind: ${model['kind']}',
    ),
  };

  static double _linearCombination(
    Map<String, Object?> model,
    List<double> basis,
  ) {
    final coefficients = model['coefficients']! as List<Object?>;
    var result = (model['intercept']! as num).toDouble();
    for (var index = 0; index < basis.length; index += 1) {
      result += (coefficients[index]! as num).toDouble() * basis[index];
    }
    return result;
  }

  static List<double> _gamBasis(
    List<double> features,
    List<Object?> knots,
  ) {
    final result = <double>[];
    for (var feature = 0; feature < features.length; feature += 1) {
      final value = features[feature];
      result.add(value);
      final featureKnots = knots[feature]! as List<Object?>;
      if (featureKnots.length != 4) {
        continue;
      }
      final first = (featureKnots.first! as num).toDouble();
      final secondLast = (featureKnots[2]! as num).toDouble();
      final last = (featureKnots.last! as num).toDouble();
      final rangeSquared = (last - first) * (last - first);
      final tailDistance = last - secondLast;
      for (var knot = 0; knot < 2; knot += 1) {
        final current = (featureKnots[knot]! as num).toDouble();
        final currentCubic = math.pow(math.max(value - current, 0), 3).toDouble() / rangeSquared;
        final secondLastCubic = math.pow(math.max(value - secondLast, 0), 3).toDouble() / rangeSquared;
        final lastCubic = math.pow(math.max(value - last, 0), 3).toDouble() / rangeSquared;
        result.add(
          currentCubic -
              secondLastCubic * (last - current) / tailDistance +
              lastCubic * (secondLast - current) / tailDistance,
        );
      }
    }
    return result;
  }

  static double _treeEnsemble(
    Map<String, Object?> model,
    List<double> features,
  ) {
    var prediction = (model['bias']! as num).toDouble();
    final rate = (model['learningRate']! as num).toDouble();
    for (final tree in model['trees']! as List<Object?>) {
      prediction += rate * _tree(tree! as List<Object?>, features);
    }
    return prediction;
  }

  static double _tree(List<Object?> tree, List<double> features) {
    var node = 0;
    while (true) {
      final offset = node * 5;
      final feature = (tree[offset]! as num).toInt();
      if (feature == -1) {
        return (tree[offset + 4]! as num).toDouble();
      }
      node = features[feature] <= (tree[offset + 1]! as num).toDouble()
          ? (tree[offset + 2]! as num).toInt()
          : (tree[offset + 3]! as num).toInt();
    }
  }

  static double _gateProbability(
    Map<String, Object?> gate,
    List<double> features,
  ) {
    if (gate['fitted'] != true) {
      return (gate['priorProbability'] as num?)?.toDouble() ?? 1;
    }
    final standardized = _standardize(gate, features);
    final basis = <double>[
      ...standardized,
      for (final feature in standardized) feature * feature,
    ];
    final linear = (gate['intercept']! as num).toDouble() + _dot(gate['coefficients']! as List<Object?>, basis);
    if (linear >= 0) {
      return 1 / (1 + math.exp(-linear));
    }
    final exponential = math.exp(linear);
    return exponential / (1 + exponential);
  }

  static double _dot(List<Object?> coefficients, List<double> values) {
    var result = 0.0;
    for (var index = 0; index < values.length; index += 1) {
      result += (coefficients[index]! as num).toDouble() * values[index];
    }
    return result;
  }

  static double _distanceSupportWeight(
    Map<String, Object?> schema,
    List<double> features,
    double transitionScale,
  ) {
    final centers = schema['medians']! as List<Object?>;
    final scales = schema['madScales']! as List<Object?>;
    var squaredDistance = 0.0;
    for (var index = 0; index < features.length; index += 1) {
      final standardized = (features[index] - (centers[index]! as num).toDouble()) / (scales[index]! as num).toDouble();
      squaredDistance += standardized * standardized;
    }
    final distance = math.sqrt(squaredDistance / features.length);
    final inner = (schema['distanceInner']! as num).toDouble() * transitionScale;
    final outer = math.max(
      (schema['distanceOuter']! as num).toDouble() * transitionScale,
      inner + 0.000001,
    );
    if (distance <= inner) {
      return 1;
    }
    if (distance >= outer) {
      return 0;
    }
    return (outer - distance) / (outer - inner);
  }
}
